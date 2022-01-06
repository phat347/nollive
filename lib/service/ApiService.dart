import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:livekit_example/model/appConfig.dart';
import 'package:livekit_example/model/getRoomInfoResponse.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dio/src/headers.dart' as _header;

part 'ApiService.g.dart';
dynamic errorInterceptor(DioError dioError, ErrorInterceptorHandler handler) async {
  if (
  dioError.response != null &&
      (dioError.response!.statusCode ?? 0) < 200 ||
      (dioError.response!.statusCode ?? 0) > 300
  ) {
    AppConfig.showToast('Không thể lấy thông tin phòng!');
    print(dioError.message);

    handler.next(
        DioError(
            requestOptions: dioError.requestOptions,
            error:dioError.response!.data)
    );

  }
}

@RestApi(baseUrl: AppConfig.baseURL)
abstract class ApiService {
  factory ApiService(Dio dio, {String baseUrl}) = _ApiService;

  static ApiService create() {
    final dio = Dio();
    (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
        (HttpClient client) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      return client;
    };
    dio.options.headers["content-type"] = 'multipart/form-data';
    dio.options.connectTimeout = 60000;
    dio.interceptors.add(PrettyDioLogger());
    dio.interceptors.add(InterceptorsWrapper(
        onError: (DioError dioError, ErrorInterceptorHandler handler) => errorInterceptor(dioError, handler))
    );
    return ApiService(dio);
  }

  @POST('/get_single_room_info')
  @MultiPart()
  Future<GetRoomInfoResponse> getSingleRoomInfo(@Part() String room);


}