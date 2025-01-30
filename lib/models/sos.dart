import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class SOS {
  final Telephony telephony = Telephony.instance;

  // Request SMS and Location Permissions
  Future<void> requestPermissions() async {
    await Permission.location.request();
    await Permission.sms.request();
  }

  // Get User's Current Location
  Future<String?> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
    } catch (e) {
      print("Error getting location: $e");
      return null;
    }
  }

  // Send SOS SMS with Current Location to Emergency Contact
  void sendSOSMessage(String emergencyContact1) async {
    bool? smsCanBeSent = await telephony.requestSmsPermissions;
    if (!smsCanBeSent!) {
      print("SMS permission not allowed by device settings.");
      return;
    }

    String? locationLink = await getCurrentLocation();
    if (locationLink != null) {
      String message = "🚨 SOS! I need help. My location: $locationLink";

      try {
        await telephony.sendSmsByDefaultApp(
          to: emergencyContact1, // Send to the emergency contact number
          message: message,
        );
        print("SOS message sent successfully!");
      } catch (e) {
        print("Failed to send SMS: $e");
      }
    } else {
      print("Could not retrieve location.");
    }
  }
}
