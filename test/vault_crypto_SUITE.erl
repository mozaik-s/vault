%%%-------------------------------------------------------------------
%% Common Test suite for vault_crypto
%%%-------------------------------------------------------------------
-module(vault_crypto_SUITE).

-include_lib("common_test/include/ct.hrl").

%% Suite exports
-export([
  all/0,
  init_per_suite/1,
  end_per_suite/1,
  init_per_testcase/2,
  end_per_testcase/2
]).

%% Test cases
-export([
  test_sign_verify_roundtrip/1,
  test_verify_invalid_signature/1,
  test_encrypt_decrypt_roundtrip/1,
  test_decrypt_tampered/1,
  test_encrypt_wrong_key_size/1
]).

%% ===================================================================
%% Type specs
%% ===================================================================

-spec all() -> [atom()].
-spec init_per_suite(list()) -> list().
-spec end_per_suite(list()) -> ok.
-spec init_per_testcase(atom(), list()) -> list().
-spec end_per_testcase(atom(), list()) -> ok.
-spec test_sign_verify_roundtrip(list()) -> ok.
-spec test_verify_invalid_signature(list()) -> ok.
-spec test_encrypt_decrypt_roundtrip(list()) -> ok.
-spec test_decrypt_tampered(list()) -> ok.
-spec test_encrypt_wrong_key_size(list()) -> ok.

%% ===================================================================
%% Suite callbacks
%% ===================================================================

all() ->
  [
    test_sign_verify_roundtrip,
    test_verify_invalid_signature,
    test_encrypt_decrypt_roundtrip,
    test_decrypt_tampered,
    test_encrypt_wrong_key_size
  ].

init_per_suite(Config) ->
  Config.

end_per_suite(_Config) ->
  ok.

init_per_testcase(_Case, Config) ->
  Config.

end_per_testcase(_Case, _Config) ->
  ok.

%% ===================================================================
%% Test cases
%% ===================================================================

test_sign_verify_roundtrip(_Config) ->
  {PublicKey, PrivateKey} = crypto:generate_key(eddsa, ed25519),
  Data = crypto:strong_rand_bytes(64),
  {ok, Signature} = vault_crypto:sign(Data, PrivateKey),
  {ok, verified} = vault_crypto:verify(Data, Signature, PublicKey),
  ok.

test_verify_invalid_signature(_Config) ->
  {PublicKey, PrivateKey} = crypto:generate_key(eddsa, ed25519),
  Data = crypto:strong_rand_bytes(64),
  {ok, _ValidSig} = vault_crypto:sign(Data, PrivateKey),
  InvalidSignature = crypto:strong_rand_bytes(64),
  {error, invalid} = vault_crypto:verify(Data, InvalidSignature, PublicKey),
  ok.

test_encrypt_decrypt_roundtrip(_Config) ->
  Key = crypto:strong_rand_bytes(32),
  PlainText = crypto:strong_rand_bytes(1024),
  {ok, CipherBinary} = vault_crypto:encrypt(PlainText, Key),
  {ok, Decrypted} = vault_crypto:decrypt(CipherBinary, Key),
  PlainText = Decrypted,
  ok.

test_decrypt_tampered(_Config) ->
  Key = crypto:strong_rand_bytes(32),
  PlainText = crypto:strong_rand_bytes(64),
  {ok, <<Header:28/binary, CipherText/binary>>} = vault_crypto:encrypt(PlainText, Key),
  %% Flip the first byte of the ciphertext portion
  <<First, Rest/binary>> = CipherText,
  TamperedCipher = <<Header/binary, (First bxor 1), Rest/binary>>,
  {error, decryption_failed} = vault_crypto:decrypt(TamperedCipher, Key),
  ok.

test_encrypt_wrong_key_size(_Config) ->
  Key = crypto:strong_rand_bytes(16),
  Data = crypto:strong_rand_bytes(32),
  {error, _} = vault_crypto:encrypt(Data, Key),
  ok.
