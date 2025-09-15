class NoxDataModel {
  final String ruc;
  final int down;
  final int up;
  final int edFd;
  final int satelital;
  final int radioEnlace;
  final int rpaPower;
  final int rpaRouter;
  final int rpaOnulos;
  final int rpaOltlos;
  final int suspendido;
  final int baja;

  NoxDataModel({
    required this.ruc,
    required this.down,
    required this.up,
    required this.edFd,
    required this.satelital,
    required this.radioEnlace,
    required this.rpaPower,
    required this.rpaRouter,
    required this.rpaOnulos,
    required this.rpaOltlos,
    required this.suspendido,
    required this.baja,
  });

  factory NoxDataModel.fromJson(Map<String, dynamic> json) {
    final data = json['DATA'];
    return NoxDataModel(
      ruc: data['RUC'] ?? '',
      down: data['DOWN'] ?? 0,
      up: data['UP'] ?? 0,
      edFd: data['ED_FD'] ?? 0, //Enlace Direct. Fibra Direct.
      satelital: data['Satelital'] ?? 0,
      radioEnlace: data['Radio_Enlace'] ?? 0,
      rpaPower: data['RPA_POWER'] ?? 0,
      rpaRouter: data['RPA_ROUTER'] ?? 0,
      rpaOnulos: data['RPA_ONULOS'] ?? 0,
      rpaOltlos: data['RPA_OLTLOS'] ?? 0,
      suspendido: data['Suspendido'] ?? 0,
      baja: data['Baja'] ?? 0,
    );
  }
}
