import 'package:dio/dio.dart';
import 'package:livekit_example/service/ServiceError.dart';

class ServiceHepler {

  static ServiceError handleErrorResponse(DioError errorResponse) {

    if (
    errorResponse.response != null &&
        (errorResponse.response!.statusCode ?? 0) >= 200 &&
        (errorResponse.response!.statusCode ?? 0) <= 300
    ) {
      /// Succesfully
      return ServiceError(errorResponse.response?.statusCode ?? 0, '', true);
    }
    else {
      /// Error
      return ServiceError.initError(errorResponse);
    }
  }

}