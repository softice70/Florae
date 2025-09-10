import 'package:florae/models/plant.dart';
import 'package:florae/models/care.dart';

class CareHistoryItem {
  final DateTime date;
  final Plant plant;
  final List<CareHistoryDetail> careDetails;

  CareHistoryItem({
    required this.date,
    required this.plant,
    required this.careDetails,
  });
}

class CareHistoryDetail {
  final String careName;
  final String? notes;
  final DateTime careDate;
  final Care care;

  CareHistoryDetail({
    required this.careName,
    this.notes,
    required this.careDate,
    required this.care,
  });
}