%%%-------------------------------------------------------------------
%% @doc Vault cryptographic operations
%% Library module (no gen_server) providing signing, verification, encryption, decryption
%%%-------------------------------------------------------------------
-module(vault_crypto).

%% API - pure cryptographic functions
-export([
  sign/2,
  verify/3,
  encrypt/2,
  decrypt/2
]).

%% @doc Sign data with private key using Ed25519
-spec sign(binary(), binary()) -> {ok, binary()} | {error, term()}.
sign(_Data, _PrivateKey) ->
  % TODO: Use enacl library for Ed25519 signing
  % enacl:sign_detached(Data, PrivateKey)
  logger:debug("Signing data with Ed25519", []),
  {error, not_implemented}.

%% @doc Verify signature with public key using Ed25519
-spec verify(binary(), binary(), binary()) -> {ok, verified} | {error, invalid}.
verify(_Data, _Signature, _PublicKey) ->
  % TODO: Use enacl library for Ed25519 verification
  % enacl:verify_detached(Signature, Data, PublicKey)
  logger:debug("Verifying Ed25519 signature", []),
  {error, not_implemented}.

%% @doc Encrypt data with AES-256
-spec encrypt(binary(), binary()) -> {ok, binary()} | {error, term()}.
encrypt(_Data, _Key) ->
  % TODO: Use enacl library for AES-256 encryption
  % enacl:secretbox(Data, Nonce, Key)
  logger:debug("Encrypting data with AES-256", []),
  {error, not_implemented}.

%% @doc Decrypt data with AES-256
-spec decrypt(binary(), binary()) -> {ok, binary()} | {error, term()}.
decrypt(_EncryptedData, _Key) ->
  % TODO: Use enacl library for AES-256 decryption
  % enacl:secretbox_open(EncryptedData, Nonce, Key)
  logger:debug("Decrypting data with AES-256", []),
  {error, not_implemented}.
