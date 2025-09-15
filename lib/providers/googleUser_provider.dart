import '../models/googleUser.dart';
import 'package:flutter/material.dart';

class GoogleUserProvider with ChangeNotifier {
  GoogleUser? _user;

  GoogleUser? get user => _user;

  void setUser(GoogleUser user) {
    _user = user;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }
}
