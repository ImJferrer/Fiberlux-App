import 'package:flutter/material.dart';

class LoaderProvider with ChangeNotifier {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void showLoader() {
    _isLoading = true;
    notifyListeners();
  }

  void hideLoader() {
    _isLoading = false;
    notifyListeners();
  }
}
