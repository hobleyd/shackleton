import '../../models/app_statistics.dart';

abstract class IAppStatisticsRepository {
  Future<AppStatistics> getStatistics();
  void clear();
}
