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
sign(Data, PrivateKey) ->
  try
    Signature = crypto:sign(eddsa, none, Data, [PrivateKey, ed25519]),
    {ok, Signature}
  catch
    _:Reason -> {error, Reason}
  end.

%% @doc Verify signature with public key using Ed25519
-spec verify(binary(), binary(), binary()) -> {ok, verified} | {error, invalid | term()}.
verify(Data, Signature, PublicKey) ->
  try
    case crypto:verify(eddsa, none, Data, Signature, [PublicKey, ed25519]) of
      true -> {ok, verified};
      false -> {error, invalid}
    end
  catch
    _:Reason -> {error, Reason}
  end.

%% @doc Encrypt data with AES-256-GCM. Key must be 32 bytes.
%% Returns <<IV:12/binary, Tag:16/binary, CipherText/binary>>.
-spec encrypt(binary(), binary()) -> {ok, binary()} | {error, term()}.
encrypt(Data, Key) ->
  try
    IV = crypto:strong_rand_bytes(12),
    {CipherText, Tag} = crypto:crypto_one_time_aead(aes_256_gcm, Key, IV, Data, <<>>, 16, true),
    {ok, <<IV:12/binary, Tag:16/binary, CipherText/binary>>}
  catch
    _:Reason -> {error, Reason}
  end.

%% @doc Decrypt AES-256-GCM ciphertext produced by encrypt/2.
-spec decrypt(binary(), binary()) -> {ok, binary()} | {error, term()}.
decrypt(<<IV:12/binary, Tag:16/binary, CipherText/binary>>, Key) ->
  try
    case crypto:crypto_one_time_aead(aes_256_gcm, Key, IV, CipherText, <<>>, Tag, false) of
      error -> {error, decryption_failed};
      PlainText -> {ok, PlainText}
    end
  catch
    _:Reason -> {error, Reason}
  end;
decrypt(_CipherBinary, _Key) ->
  {error, decryption_failed}.
