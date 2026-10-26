import '../../core/api_client.dart';
import 'report.dart';

class ReportRepository {
  ReportRepository(this._api);

  final ApiClient _api;

  Future<MonthlyReport> monthly(String month) async {
    final response = await _api.dio.get('/reports/monthly', queryParameters: {'month': month});
    final body = response.data as Map<String, dynamic>;

    return MonthlyReport.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<List<DailyTotal>> daily(String month) async {
    final response = await _api.dio.get('/reports/daily', queryParameters: {'month': month});
    final body = response.data as Map<String, dynamic>;

    return (body['data'] as List)
        .map((item) => DailyTotal.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}