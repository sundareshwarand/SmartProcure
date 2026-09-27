import '../models/farmer.dart';
import '../models/centre.dart';
import '../models/booking.dart';

class MockRepository {
  // Provide realistic demo data for Phase 1
  Future<Farmer> fetchFarmerProfile() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return Farmer(id: 'F-1001', name: 'Ravi Kumar', village: 'Example Village', district: 'Example District', mobile: '9876543210', preferredLanguage: 'en');
  }

  Future<List<Centre>> fetchCentres() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.generate(5, (i) => Centre(id: 'C${i+1}', name: 'Central Procurement Centre ${i+1}', distanceKm: (i+1)*2.1, currentQueue: 10+(i*5), capacityToday: 200 - (i*20)));
  }

  Future<List<Booking>> fetchBookings() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Booking(id: 'B-1001', token: 'SP-1047', centreName: 'Central Procurement Centre 2', date: DateTime.now().add(const Duration(days:1)), slot: '10:00 - 11:00')
    ];
  }
}
