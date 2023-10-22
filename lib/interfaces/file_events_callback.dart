import '../models/file_of_interest.dart';

abstract class FileEventsCallback {
  void remove(FileOfInterest entity);
}