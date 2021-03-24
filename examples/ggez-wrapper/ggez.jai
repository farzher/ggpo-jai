ggez_init :: (gamestateptr: *$GameState, inputptr: *$Input, updatefn: ()->(), localport:u16, playerinfo: []string) {
  ggpo_init_winsock();

  _GameState = GameState;
  _Input = Input;
  _gamestateptr = xx gamestateptr;
  _inputptr = xx inputptr;
  sizeofgamestate = size_of(GameState);
  sizeofinput = size_of(Input);
  _updatefn = updatefn;

  cb.begin_game      = (gamename: cstring) -> bool #c_call { return true; };
  cb.save_game_state = (buffer: * *u8, len: *s32, checksum: *s32, frame: s32) -> bool #c_call { new_context: Context; push_context new_context {
    <<buffer = alloc(sizeofgamestate);
    <<len = sizeofgamestate;
    memcpy(<<buffer, _gamestateptr, sizeofgamestate);
    return true;
  }};
  cb.load_game_state = (buffer: *u8, len: s32) -> bool #c_call { new_context: Context; push_context new_context {
    memcpy(_gamestateptr, buffer, len);
    return true;
  }};
  cb.log_game_state  = (filename: cstring, buffer: *u8, len: s32) -> bool #c_call { new_context: Context; push_context new_context {
    return true;
  }};
  cb.free_buffers    = (buffer: *void) -> void #c_call { new_context: Context; push_context new_context {
    free(buffer);
  }};
  cb.advance_frame   = (flags: s32) -> bool #c_call { new_context: Context; push_context new_context {
    ggpo_synchronize_input(ggpo, *inputvalues, size_of(type_of(inputvalues)), *disconnect_flags);
    _updatefn();
    ggpo_advance_frame(ggpo);
    return true;
  }};
  cb.on_event        = (event: *GGPOEvent) -> bool #c_call { new_context: Context; push_context new_context {
    if event.code == {
      case .GGPO_EVENTCODE_TIMESYNC;
        skipframes += event.timesync.frames_ahead;
    }
    return true;
  }};

  ggpo_start_session(*ggpo, *cb, "ggez", num_players=GGPO_PLAYERCOUNT, input_size=sizeofinput, localport=localport);
  ggpo_set_disconnect_timeout(ggpo, 3000);
  ggpo_set_disconnect_notify_start(ggpo, 1000);

  for * player, i: players {
    playerinfoarg := playerinfo[i];
    player.size = size_of(GGPOPlayer);
    player.player_num = cast(s32) i+1;
    if playerinfoarg == "local" {
      player.type = .GGPO_PLAYERTYPE_LOCAL;
      localplayerindex = i;
    } else {
      player.type = .GGPO_PLAYERTYPE_REMOTE;
      ipport := String.split(playerinfoarg, ":");
      ip := ipport[0];
      memcpy(player.remote.ip_address.data, ip.data, ip.count);
      player.remote.port = xx to_integer(ipport[1]);
    }

    ggpo_add_player(ggpo, player, *handles[i]);
    if player.type == .GGPO_PLAYERTYPE_LOCAL ggpo_set_frame_delay(ggpo, handles[i], 0);
  }
}

ggez_inputs :: () -> type_of(inputvalues) {return inputvalues; }
ggez_update :: () {
  if skipframes > 0 {
    skipframes -= 1;
    return;
  }

  ggpo_idle(ggpo, 5); // todo: this is probably adding input delay. need to move it
  if .GGPO_OK != ggpo_add_local_input(ggpo, handles[localplayerindex], _inputptr, sizeofinput) return;
  if .GGPO_OK != ggpo_synchronize_input(ggpo, *inputvalues, size_of(type_of(inputvalues)), *disconnect_flags) return;

  _updatefn();
  ggpo_advance_frame(ggpo);
}






#import "ggpo";
String :: #import "String";

ggpo: *GGPOSession;
cb: GGPOSessionCallbacks;
disconnect_flags: s32;
localplayerindex: int;
GGPO_PLAYERCOUNT :: 2;
inputvalues: [GGPO_PLAYERCOUNT]Input;
handles: [GGPO_PLAYERCOUNT]GGPOPlayerHandle;
players: [GGPO_PLAYERCOUNT]GGPOPlayer;

skipframes: int;

_GameState: Type;
_Input: Type;
_gamestateptr: *void;//*GameState;
_inputptr: *void;//*Input
sizeofgamestate: s32;
sizeofinput: s32;
_updatefn: ()->();










cstring :: *u8;
fromcstr :: (cstr: cstring) -> string {
  ret: string;
  if (cstr == null) return ret;
  ret.data = xx cstr;
  ret.count = c_style_strlen(xx cstr);
  return ret;
}

getms :: () -> float64 {
  return cast(float64)(get_time()*1000);
}
