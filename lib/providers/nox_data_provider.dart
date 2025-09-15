import 'package:flutter/material.dart';
import '../models/nox_data_model.dart';

class NoxDataProvider extends ChangeNotifier {
  NoxDataModel? _noxData;

  NoxDataModel? get noxData => _noxData;

  void setNoxData(NoxDataModel data) {
    _noxData = data;
    notifyListeners();
  }

  void clearNoxData() {
    _noxData = null;
    notifyListeners();
  }
}
