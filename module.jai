winsocklib :: #foreign_system_library "ws2_32"; // ggpo dependency
WSADESCRIPTION_LEN :: 256;
WSASYS_STATUS_LEN  :: 128;
WSAData :: struct {
  wVersion       : u16;
  wHighVersion   : u16;
  iMaxSockets    : u16;
  iMaxUdpDg      : u16;
  lpVendorInfo   : *u8;
  szDescription  : [WSADESCRIPTION_LEN+1] u8;
  szSystemStatus : [WSASYS_STATUS_LEN+1] u8;
}
MAKEWORD :: inline (low: u8, high: u8) -> u16 {
  result : u16 = (high << 8) | low;
  return result;
}
WSAStartup :: (version: u16, wsaData: *WSAData) -> u32 #foreign winsocklib;
WSACleanup :: () -> s32 #foreign winsocklib;
ggpo_init_winsock :: () -> success: bool {
  wsa: WSAData;
  return 0 != WSAStartup(#run MAKEWORD(2,2), *wsa);
}
ggpo_cleanup_winsock :: () { WSACleanup(); }





ggpolib :: #foreign_library,no_dll "win/ggpo";

GGPOSession :: struct {};
GGPOPlayerHandle :: s32;
GGPOPlayerType :: enum s32 {GGPO_PLAYERTYPE_LOCAL; GGPO_PLAYERTYPE_REMOTE; GGPO_PLAYERTYPE_SPECTATOR;};

GGPOPlayer :: struct {
  size: s32;
  type: GGPOPlayerType;
  player_num: s32;
  remote: struct {ip_address: [32]u8; port: u16; }
}

GGPOErrorCode :: enum s32 {
  GGPO_OK                              ::  0;
  GGPO_ERRORCODE_SUCCESS               ::  0;
  GGPO_ERRORCODE_GENERAL_FAILURE       :: -1;
  GGPO_ERRORCODE_INVALID_SESSION       ::  1;
  GGPO_ERRORCODE_INVALID_PLAYER_HANDLE ::  2;
  GGPO_ERRORCODE_PLAYER_OUT_OF_RANGE   ::  3;
  GGPO_ERRORCODE_PREDICTION_THRESHOLD  ::  4;
  GGPO_ERRORCODE_UNSUPPORTED           ::  5;
  GGPO_ERRORCODE_NOT_SYNCHRONIZED      ::  6;
  GGPO_ERRORCODE_IN_ROLLBACK           ::  7;
  GGPO_ERRORCODE_INPUT_DROPPED         ::  8;
  GGPO_ERRORCODE_PLAYER_DISCONNECTED   ::  9;
  GGPO_ERRORCODE_TOO_MANY_SPECTATORS   :: 10;
  GGPO_ERRORCODE_INVALID_REQUEST       :: 11;
}

GGPOEventCode :: enum s32 {
  GGPO_EVENTCODE_CONNECTED_TO_PEER       :: 1000;
  GGPO_EVENTCODE_SYNCHRONIZING_WITH_PEER :: 1001;
  GGPO_EVENTCODE_SYNCHRONIZED_WITH_PEER  :: 1002;
  GGPO_EVENTCODE_RUNNING                 :: 1003;
  GGPO_EVENTCODE_DISCONNECTED_FROM_PEER  :: 1004;
  GGPO_EVENTCODE_TIMESYNC                :: 1005;
  GGPO_EVENTCODE_CONNECTION_INTERRUPTED  :: 1006;
  GGPO_EVENTCODE_CONNECTION_RESUMED      :: 1007;
}
GGPOEvent :: struct {
  code: GGPOEventCode;
  union {
    connected: struct { player: GGPOPlayerHandle; };
    synchronizing: struct { player: GGPOPlayerHandle; count: s32; total: s32; };
    synchronized: struct { player: GGPOPlayerHandle; };
    disconnected: struct { player: GGPOPlayerHandle; };
    timesync: struct { frames_ahead: s32; };
    connection_interrupted: struct { player: GGPOPlayerHandle; disconnect_timeout: s32; };
    connection_resumed: struct { player: GGPOPlayerHandle; };
  }
}


GGPOSessionCallbacks :: struct {
  begin_game     : (gamename: *u8) -> bool #c_call;
  save_game_state: (buffer: * *u8, len: *s32, checksum: *s32, frame: s32) -> bool #c_call;
  load_game_state: (buffer: *u8, len: s32) -> bool #c_call;
  log_game_state : (filename: *u8, buffer: *u8, len: s32) -> bool #c_call;
  free_buffers   : (buffer: *void) -> void #c_call;
  advance_frame  : (flags: s32) -> bool #c_call;
  on_event       : (info: *GGPOEvent) -> bool #c_call;
}

GGPONetworkStats :: struct {
  network: struct {send_queue_len: s32; recv_queue_len: s32; ping: s32; kbps_sent: s32; }
  timesync: struct {local_frames_behind: s32; remote_frames_behind: s32; }
}

ggpo_start_session              :: (session:**GGPOSession, cb: *GGPOSessionCallbacks, game: *u8, num_players: s32, input_size: s32, localport: u16) -> GGPOErrorCode #foreign ggpolib;
ggpo_start_synctest             :: (session:**GGPOSession, cb: *GGPOSessionCallbacks, game: *u8, num_players: s32, input_size: s32, frames: s32)    -> GGPOErrorCode #foreign ggpolib;
ggpo_start_spectating           :: (session:**GGPOSession, cb: *GGPOSessionCallbacks, game: *u8, num_players: s32, input_size: s32, local_port: u16, host_ip: *u8, host_port: u16) -> GGPOErrorCode #foreign ggpolib;
ggpo_synchronize_input          :: (session: *GGPOSession, values: *void, size: s32, disconnect_flags: *s32)                                        -> GGPOErrorCode #foreign ggpolib;
ggpo_add_player                 :: (session: *GGPOSession, player: *GGPOPlayer, handle: *GGPOPlayerHandle)                                          -> GGPOErrorCode #foreign ggpolib;
ggpo_add_local_input            :: (session: *GGPOSession, player: GGPOPlayerHandle, values: *void, size: s32)                                      -> GGPOErrorCode #foreign ggpolib;
ggpo_set_frame_delay            :: (session: *GGPOSession, player: GGPOPlayerHandle, frame_delay: s32)                                              -> GGPOErrorCode #foreign ggpolib;
ggpo_disconnect_player          :: (session: *GGPOSession, player: GGPOPlayerHandle)                                                                -> GGPOErrorCode #foreign ggpolib;
ggpo_get_network_stats          :: (session: *GGPOSession, player: GGPOPlayerHandle, stats: *GGPONetworkStats)                                      -> GGPOErrorCode #foreign ggpolib;
ggpo_set_disconnect_timeout     :: (session: *GGPOSession, timeout: s32)                                                                            -> GGPOErrorCode #foreign ggpolib;
ggpo_set_disconnect_notify_start:: (session: *GGPOSession, timeout: s32)                                                                            -> GGPOErrorCode #foreign ggpolib;
ggpo_idle                       :: (session: *GGPOSession, timeout: s32)                                                                            -> GGPOErrorCode #foreign ggpolib;
ggpo_advance_frame              :: (session: *GGPOSession)                                                                                          -> GGPOErrorCode #foreign ggpolib;
ggpo_close_session              :: (session: *GGPOSession)                                                                                          -> GGPOErrorCode #foreign ggpolib;
ggpo_log                        :: (session: *GGPOSession, fmt: *u8)                                                                                -> GGPOErrorCode #foreign ggpolib;
ggpo_logv                       :: (session: *GGPOSession, fmt: *u8, args: *u8)                                                                     -> GGPOErrorCode #foreign ggpolib;
