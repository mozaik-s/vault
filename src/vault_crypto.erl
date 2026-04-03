%%%-------------------------------------------------------------------
%% @doc Vault cryptographic operations service
%% Provides signing, verification, encryption, decryption via libsodium
%%%-------------------------------------------------------------------
-module(vault_crypto).

-behaviour(gen_server).

%% API
-export([
  start_link/0,
  sign/2,
  verify/3,
  encrypt/2,
  decrypt/2
]).

%% gen_server callbacks
-export([
  init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3
]).

-record(state, {}).

%% ===================================================================
%% API
%% ===================================================================

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Sign data with private key using Ed25519
-spec sign(binary(), binary()) -> {ok, binary()} | {error, term()}.
sign(Data, PrivateKey) ->
  gen_server:call(?MODULE, {sign, Data, PrivateKey}).

%% @doc Verify signature with public key using Ed25519
-spec verify(binary(), binary(), binary()) -> {ok, verified} | {error, invalid}.
verify(Data, Signature, PublicKey) ->
  gen_server:call(?MODULE, {verify, Data, Signature, PublicKey}).

%% @doc Encrypt data with AES-256
-spec encrypt(binary(), binary()) -> {ok, binary()} | {error, term()}.
encrypt(Data, Key) ->
  gen_server:call(?MODULE, {encrypt, Data, Key}).

%% @doc Decrypt data with AES-256
-spec decrypt(binary(), binary()) -> {ok, binary()} | {error, term()}.
decrypt(EncryptedData, Key) ->
  gen_server:call(?MODULE, {decrypt, EncryptedData, Key}).

%% ===================================================================
%% gen_server callbacks
%% ===================================================================

init([]) ->
  State = #state{},
  {ok, State}.

handle_call({sign, Data, PrivateKey}, _From, State) ->
  % TODO: Use enacl library for Ed25519 signing
  % enacl:sign_detached(Data, PrivateKey)
  logger:debug("Signing data with Ed25519", []),
  {reply, {error, not_implemented}, State};

handle_call({verify, Data, Signature, PublicKey}, _From, State) ->
  % TODO: Use enacl library for Ed25519 verification
  % enacl:verify_detached(Signature, Data, PublicKey)
  logger:debug("Verifying Ed25519 signature", []),
  {reply, {error, not_implemented}, State};

handle_call({encrypt, Data, Key}, _From, State) ->
  % TODO: Use enacl library for AES-256 encryption
  % enacl:secretbox(Data, Nonce, Key)
  logger:debug("Encrypting data with AES-256", []),
  {reply, {error, not_implemented}, State};

handle_call({decrypt, EncryptedData, Key}, _From, State) ->
  % TODO: Use enacl library for AES-256 decryption
  % enacl:secretbox_open(EncryptedData, Nonce, Key)
  logger:debug("Decrypting data with AES-256", []),
  {reply, {error, not_implemented}, State};

handle_call(_Request, _From, State) ->
  {reply, {error, unknown_call}, State}.

handle_cast(_Request, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
