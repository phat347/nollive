import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

class ServiceError extends ChangeNotifier {

  int statusCode;
  String message;
  bool success;

  ServiceError(this.statusCode, this.message, this.success);

  ServiceError.initError(DioError error):
        statusCode = error.response?.statusCode ?? 0,
        success = false,
        message = error.response?.statusMessage ?? '';


}