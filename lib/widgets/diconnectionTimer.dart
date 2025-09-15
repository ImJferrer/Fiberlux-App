// import 'dart:async';

// import 'package:fiberlux_app/providers/graph_socket_provider.dart';
// import 'package:flutter/material.dart';

// class DisconnectionTimer extends StatefulWidget {
//   final GraphSocketProvider provider;
//   const DisconnectionTimer({Key? key, required this.provider})
//       : super(key: key);

//   @override
//   _DisconnectionTimerState createState() => _DisconnectionTimerState();
// }

// class _DisconnectionTimerState extends State<DisconnectionTimer> {
//   late Timer _timer;

//   @override
//   void initState() {
//     super.initState();
//     _timer = Timer.periodic(const Duration(seconds: 1), (_) {
//       if (!mounted) return;
//       if (widget.provider.isConnected) return;
//       setState(() {});
//     });
//   }

//   @override
//   void dispose() {
//     _timer.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final dur = widget.provider.disconnectedDuration;
//     final minutes = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
//     final seconds = dur.inSeconds.remainder(60).toString().padLeft(2, '0');
//     return Text(
//       '$minutes:$seconds',
//       style: const TextStyle(
//         color: Colors.red,
//         fontWeight: FontWeight.bold,
//       ),
//     );
//   }
// }
