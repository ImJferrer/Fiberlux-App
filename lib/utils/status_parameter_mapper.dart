class StatusParameterMapper {
  static final Map<String, String> _statusToParameter = {
    'ACTIVO': 'UP',
    'FALTA DE CORRIENTE': 'POWER',
    'AVERÍA ZONAL': 'ZONE',
    'CAÍDA DE LA FIBRA': 'FIBER',
  };

  static String getParameterForStatus(String status) {
    return _statusToParameter[status] ?? 'UP';
  }

  static String getDisplayNameForStatus(String status) {
    switch (status) {
      case 'ACTIVO':
        return 'Servicios Activos';
      case 'FALTA DE CORRIENTE':
        return 'Falta de Corriente';
      case 'AVERÍA ZONAL':
        return 'Averías Zonales';
      case 'CAÍDA DE LA FIBRA':
        return 'Caídas de Fibra';
      default:
        return status;
    }
  }
}
