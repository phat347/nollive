import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AppConfig  {
  static const String baseURL = 'https://demo.nol.live:443/nol';
  static const String socketURL = 'wss://demo.nol.live:443/';
  static const String livekitURL = 'wss://demo.nol.live:443/sfu';

  static void showToast(String msg) {
    Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black45,
        textColor: Colors.white,
        fontSize: 16.0);
  }

}