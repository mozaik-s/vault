# Vault

> Pure Erlang OTP library for encrypted asset storage - powers Mozaik

**Vault** is a reusable Erlang OTP application providing secure encrypted asset storage with cryptographic access control. It's designed to be imported as a dependency in Elixir/Phoenix applications like [Mozaik](https://github.com/mozaik/mozaik)—a privacy-first photo-sharing platform for families.

## Features

### Core Capabilities
- **End-to-End Encryption** - Assets encrypted on client before upload (AES-256)
- **Zero-Knowledge Architecture** - Server stores only encrypted blobs, never plaintext
- **Cryptographic Permissions** - Grant/revoke access using Ed25519 signatures
- **Audit Logging** - Complete access trail for compliance and security
- **User Accounts** - Secure registration and authentication with JWT

### Security Guarantees
✅ Client-side encryption before transmission  
✅ Encrypted storage (server cannot read data)  
✅ Private keys never leave client  
✅ Signature-based access control  
✅ Complete audit trail for all operations  

## Quick Start

### Prerequisites
- Erlang/OTP 25+
- Elixir 1.14+ (with Mix)
- CouchDB 3.0+
- libsodium (for cryptographic operations)

### Installation

**As a Dependency in Elixir/Phoenix:**

```elixir
# In Mozaik's mix.exs
defp deps do
  [
    {:vault, git: "https://github.com/mozaik/vault.git"}
  ]
end
```

Then in your Elixir code:
```elixir
# Call Erlang modules directly
{:ok, user} = vault_accounts:register(email, password, public_key)
{:ok, asset} = vault_assets:upload(user_id, encrypted_blob, filename)
```

**Standalone Development:**

```bash
# Clone the repository
git clone https://github.com/mozaik/vault.git
cd vault

# Install dependencies
mix deps.get

# Compile Erlang modules and Elixir code
mix compile

# Run tests (Common Test - pure Erlang)
mix test

# Start interactive shell with Vault loaded
iex -S mix
```

## Architecture

### Two-Project Model with Erlang/Elixir

**Vault** is a pure Erlang OTP library that **Mozaik (Elixir/Phoenix) imports as a dependency**:

```
┌─────────────────────────────────────────┐
│         Mozaik (Elixir/Phoenix)         │
│     Photo-sharing application           │
│  └─→ Calls Vault Erlang modules         │
└────────────────┬────────────────────────┘
                 │ Direct module calls (same BEAM VM)
┌────────────────▼────────────────────────┐
│    Vault (Pure Erlang OTP)              │
│  Encrypted asset storage library        │
└─────────────────────────────────────────┘
```

**Why this architecture:**
- ✅ No network overhead - direct function calls
- ✅ Same BEAM VM - seamless interoperability
- ✅ Erlang maturity - proven reliability in telecom
- ✅ Crypto performance - optimized for security operations
- ✅ Single deployment - combined Elixir/Erlang application

### Erlang Modules

**Vault is a single gen_server process** that manages vault operations. The core module (implemented in Erlang) is:

```erlang
% Vault gen_server for managing shards and access control
vault:start_link(VaultId, OwnerId) -> {ok, Pid}
vault:store_shard(VaultId, ShardId, EncryptedBlob) -> {ok, ShardId}
vault:get_shard(VaultId, ShardId) -> {ok, EncryptedBlob}
vault:list_shard_ids(VaultId) -> {ok, [ShardIds]}
vault:grant_shard_access(VaultId, UserId, ShardIds) -> {ok, granted}
vault:revoke_shard_access(VaultId, UserId, ShardIds) -> {ok, revoked}

% Supporting modules
vault_crypto:sign(Data, PrivateKey) -> {ok, Signature}
vault_crypto:verify(Data, Signature, PublicKey) -> {ok, verified} | {error, invalid}
vault_audit:log_access(VaultId, UserId, ShardId, Action) -> ok
```

**Key Design**: Vault stores **only shard IDs and encrypted blobs**. No asset mappings. Asset-to-shard reconstruction mappings are stored separately in Mozaik.

```erlang
% What Vault stores:
{
  vault_id => "vault_12345",
  shards => {
    shard_a1 => {encrypted_blob, hash, permissions},
    shard_b2 => {encrypted_blob, hash, permissions},
    shard_c3 => {encrypted_blob, hash, permissions}
  }
}

% What Mozaik stores (separate system):
{
  asset_id => "image_001",
  shard_ids => [shard_a1, shard_b2, shard_c3],
  reconstruction_algorithm => {...}
}
```

### Calling from Elixir (Mozaik)

```elixir
# In Mozaik's Elixir code
defmodule Mozaik.VaultClient do
  def upload_shard(vault_id, shard_id, encrypted_data) do
    # Call Erlang gen_server directly
    case vault:store_shard(vault_id, shard_id, encrypted_data) do
      {:ok, shard_id} ->
        # Store in Mozaik: which asset this shard belongs to
        {:ok, shard_id}
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  def download_shard(vault_id, shard_id) do
    case vault:get_shard(vault_id, shard_id) do
      {:ok, encrypted_data} ->
        # Reconstruct full asset using mapping in Mozaik
        {:ok, encrypted_data}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Important**: Mozaik maintains the mapping of "which shards belong to which asset". Vault has no knowledge of assets—only shards.

### Security Model

#### Shard-Based Architecture

Vault implements **separation of concerns** through distributed shards:

```
Alice uploads an image:
  1. Browser splits image into 3 shards
  2. Each shard encrypted separately (AES-256)
  3. Shard 1, 2, 3 sent to Vault server
  
Vault stores:
  ✅ Encrypted shard blobs
  ✅ Shard hashes (for integrity verification)
  ✅ Permissions on individual shards
  ❌ NO asset mapping (shards are opaque)
  ❌ NO reconstruction algorithm

Mozaik stores (separate database):
  ✅ Asset-to-shard mapping: "image_001" = [shard_1, shard_2, shard_3]
  ✅ Reconstruction algorithm (how to combine shards)
  ❌ Individual shards (never stored)

Security guarantee:
  • One database compromise = encrypted shards only (useless alone)
  • Other database compromise = mapping only (useless without shards)
  • Both compromised = still encrypted (user holds decryption keys)
```

#### Key Management

- **Encryption Keys**: AES-256 for shard encryption
- **Signature Keys**: Ed25519 for permission signing
- **Exchange Keys**: Curve25519 for key encryption (future)
- **Storage**: Private keys stored client-side only (Mozaik never has them)

## API Overview

All Vault APIs are **Erlang gen_server calls** accessed directly from Elixir code. No HTTP layer needed for internal use.

### Vault Management

```erlang
% Start a vault
{ok, Pid} = vault:start_link(VaultId, OwnerId).

% Stop a vault
ok = vault:stop(Pid).
```

### Shards

```erlang
% Store encrypted shard
{ok, ShardId} = vault:store_shard(VaultId, ShardId, EncryptedBlob).

% Download shard
{ok, EncryptedBlob} = vault:get_shard(VaultId, ShardId).

% List all shard IDs in vault
{ok, ShardIds} = vault:list_shard_ids(VaultId).

% Delete shard
ok = vault:delete_shard(VaultId, ShardId).
```

### Permissions

```erlang
% Grant user access to specific shards
{ok, granted} = vault:grant_shard_access(VaultId, UserId, [ShardId1, ShardId2]).

% Revoke user access to shards
{ok, revoked} = vault:revoke_shard_access(VaultId, UserId, [ShardId1]).

% Verify if user has access to shard
true = vault:has_access(UserId, ShardId).
```

### Audit

```erlang
% Get audit log for vault
{ok, Logs} = vault:get_audit_log(VaultId).

% Get access history for user
{ok, History} = vault:get_user_history(UserId).
```

## CouchDB Document Storage

Vault uses CouchDB with a **document-oriented approach** that separates vault state from encrypted shards:

### MVP: Single Database with Document Prefixes

**Vault Documents** (state & permissions):
```json
{
  "_id": "vault:vault_12345",
  "type": "vault",
  "owner_id": "user_456",
  "created_at": "2026-04-01T21:00:00Z",
  "permissions": [
    {"user_id": "user_789", "access_type": "view", "signature": "..."}
  ],
  "shard_references": ["shard_a1", "shard_b2", "shard_c3"],
  "audit_trail": [...]
}
```

**Shard Documents** (encrypted image data):
```json
{
  "_id": "shard:vault_12345:shard_a1",
  "type": "shard",
  "vault_id": "vault_12345",
  "shard_id": "shard_a1",
  "encrypted_blob": "<binary data>",
  "blob_hash": "sha256_...",
  "size_bytes": 1048576,
  "created_at": "2026-04-01T21:05:00Z"
}
```

**Why This Approach**:
- ✅ Logical separation: vault state vs. encrypted shards
- ✅ Security: Vault state and shards are distinct documents
- ✅ Query efficiency: Find all shards for a vault using `vault_id` prefix
- ✅ MVP simplicity: Single `mozaik_vault` CouchDB database

### Phase 2+: Multi-Database Architecture

**Future Separation** (not in MVP):
- **Vault Database**: Vault state and permissions only
- **Shard Storage**: All encrypted shards (separate CouchDB or S3/MinIO)
- **Mozaik Database**: User accounts, families, asset mappings

This provides:
- 🔒 Enhanced security (3 compromises needed for full image recovery)
- 📊 Better scaling (shard storage separated to object storage)
- 🔄 Easier replication (each database syncs independently)

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Language** | Erlang (gen_server) + Elixir (dependency) | OTP reliability + Mix ecosystem convenience |
| **Build** | Mix | Unified build tool for both Erlang & Elixir |
| **Encryption** | libsodium | Industry-standard cryptography (Ed25519, Curve25519, AES-256) |
| **Database** | CouchDB 3.0+ | Document-oriented storage for vault state (shards + permissions) |
| **Integration** | Direct Erlang calls from Elixir | No network overhead; seamless BEAM interop |
| **Testing** | Common Test (Erlang) | Pure Erlang testing framework (*_SUITE.erl) |

## Development

### Building Vault

```bash
# Install dependencies
mix deps.get

# Compile Erlang modules from src/ and run Common Test suites
mix compile

# Run tests (Common Test - pure Erlang, no ExUnit)
mix test

# Interactive shell with Vault loaded
iex -S mix
```

### Mix Configuration for Common Test

Vault is configured to compile Erlang from the `src/` directory and run **Common Test suites only** (pure Erlang testing):

```elixir
def project do
  [
    app: :vault,
    version: "0.1.0",
    erlc_paths: ["src"],           # Compile Erlang from src/
    erlc_options: [debug_info],    # Debug information
    test_pattern: "*_SUITE.erl",   # Common Test suite pattern
    # ... rest of config
  ]
end

def application do
  [
    extra_applications: [:logger],
    mod: {vault_app, []}           # Start vault_app (Erlang module)
  ]
end
```

This allows:
- Standard Erlang/OTP directory structure (`src/`)
- **Pure Erlang Common Test framework** (not ExUnit)
- Mix for building and running tests
- Integration with Mozaik's Mix environment

### Code Structure

```
vault/
├── src/                          # Erlang modules (standard Erlang location)
│   ├── vault.erl                 # Main gen_server for vault operations
│   ├── vault_sup.erl             # Supervisor
│   ├── vault_app.erl             # OTP application callback
│   ├── vault_crypto.erl          # Cryptographic operations
│   ├── vault_audit.erl           # Access logging
│   └── vault_db.erl              # CouchDB interface
├── test/
│   ├── vault_SUITE.erl           # Common Test suite for vault gen_server
│   ├── vault_crypto_SUITE.erl    # Common Test suite for crypto
│   ├── vault_audit_SUITE.erl     # Common Test suite for audit
│   └── test_helper.erl
├── mix.exs                       # Mix configuration (includes erlc_paths: ["src"])
├── mix.lock                      # Dependency lock file
└── README.md                     # This file
```

**Why this structure:**
- Erlang modules in standard `src/` directory (OTP convention)
- Mix configured to compile Erlang from `src/`
- **Tests are pure Erlang Common Test** (*_SUITE.erl files)
- Mix handles both Erlang and Elixir compilation seamlessly

### Running Tests

```bash
# Run all Common Test suites
mix test

# Run specific test suite
mix test test/vault_crypto_SUITE.erl

# Run with verbose output
mix test --trace

# Generate Common Test coverage report
mix test --cover
```

### Common Test Structure

Each test suite follows Erlang Common Test conventions:

```erlang
-module(vault_SUITE).
-include_lib("common_test/include/ct.hrl").

all() -> [
    test_store_shard,
    test_get_shard,
    test_access_control
].

% Test cases
test_store_shard(Config) ->
    % Test implementation
    ok.

test_get_shard(Config) ->
    % Test implementation
    ok.

test_access_control(Config) ->
    % Test implementation
    ok.
```

### Development Guidelines

1. **Security First** - All code handles sensitive data; review security implications
2. **Test Coverage** - Cryptographic operations require comprehensive tests
3. **Documentation** - Document all module APIs and assumptions
4. **No Plaintext Storage** - Never log or store plaintext sensitive data
5. **Error Handling** - Use proper Erlang error tuples `{error, Reason}`
6. **Supervision** - Use OTP patterns (gen_server, supervisors) for state management
7. **Interop** - Make sure Erlang modules return tuples compatible with Elixir patterns

## Documentation

Complete documentation is available in the [Mozaik Notes](https://github.com/mozaik/mozaik_notes) repository:

- **[ARCHITECTURE.md](https://github.com/mozaik/mozaik_notes/blob/main/ARCHITECTURE.md)** - System architecture overview
- **[Vault API Reference](https://github.com/mozaik/mozaik_notes/blob/main/02_architecture/vault_api.md)** - Complete API documentation
- **[Encryption Strategy](https://github.com/mozaik/mozaik_notes/blob/main/02_architecture/encryption.md)** - Cryptographic implementation details
- **[Security Model](https://github.com/mozaik/mozaik_notes/blob/main/03_security/security_principles.md)** - Threat model and security principles
- **[Database Schema](https://github.com/mozaik/mozaik_notes/blob/main/06_data/schema.md)** - Entity relationships and migrations

## Deployment

### Docker

```bash
# Build image
docker build -t vault:latest .

# Run container
docker run -e DATABASE_URL=postgresql://... vault:latest
```

### Environment Variables

```bash
DATABASE_URL=postgresql://user:password@localhost/vault_dev
SECRET_KEY_BASE=<your-secret-key>
JWT_SECRET=<your-jwt-secret>
ENV=dev
```

## Security Considerations

### What Vault Protects
- ✅ Encryption keys never stored on server
- ✅ Assets always encrypted at rest
- ✅ Permissions managed cryptographically
- ✅ Complete audit trail

### What Vault Does NOT Protect
- ❌ Metadata (who accessed what, when)
- ❌ Transport-level security (use HTTPS/TLS)
- ❌ User authentication (implement on top)

**For security concerns**, see [Security Principles](https://github.com/mozaik/mozaik_notes/blob/main/03_security/security_principles.md).

## Contributing

We welcome contributions! Please ensure:

1. All tests pass: `mix test`
2. Code is formatted: `mix format`
3. Security implications are documented
4. Changes align with the documented architecture

## License

[MIT License](LICENSE)

## Support

- 📖 [Documentation](https://github.com/mozaik/mozaik_notes)
- 🐛 [Issue Tracker](https://github.com/mozaik/vault/issues)
- 💬 [Discussions](https://github.com/mozaik/vault/discussions)

---

**Vault** is part of the **Mozaik** project—building a privacy-first future for family photo sharing.

Built with ❤️ for families who deserve better privacy.
