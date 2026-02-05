import 'package:home_widget/home_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeWidgetHelper {
  static const String androidWidgetName = 'SOSWidget';
  static const String iOSWidgetName = 'SOSWidget';

  static Future<void> initializeWidget() async {
    await HomeWidget.setAppGroupId('YOUR_APP_GROUP_ID');
  }

  static Future<void> sendLocationOnTap() async {
    try {
      // Check location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      // Get location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Create message
      String locationUrl = "https://maps.google.com/?q=${position.latitude},${position.longitude}";
      String message = "Emergency! My current location: $locationUrl";

      // Send to WhatsApp
      String phoneNumber = "919627320508";
      String whatsappUrl = "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}";

      final Uri uri = Uri.parse(whatsappUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);

    } catch (e) {
      print("Error: $e");
    }
  }
}