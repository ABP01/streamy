import 'package:agora_rtc_engine/agora_rtc_engine.dart';

// Utilitaire pour la compatibilité des handlers selon la version agora_rtc_engine 6.x
RtcEngineEventHandler buildRtcEngineEventHandler({
  required void Function(RtcConnection, int) onJoinChannelSuccess,
  required void Function(RtcConnection, int, int) onUserJoined,
  required void Function(RtcConnection, int, UserOfflineReasonType)
  onUserOffline,
}) {
  return RtcEngineEventHandler(
    onJoinChannelSuccess: onJoinChannelSuccess,
    onUserJoined: onUserJoined,
    onUserOffline: onUserOffline,
  );
}
