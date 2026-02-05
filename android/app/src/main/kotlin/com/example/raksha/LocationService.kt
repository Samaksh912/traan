package com.example.raksha

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.location.LocationManager
import android.content.Context
import android.net.Uri

class LocationService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "SEND_LOCATION") {
            sendLocation()
        }
        stopSelf()
        return START_NOT_STICKY
    }

    private fun sendLocation() {
        try {
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val location = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                ?: locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)

            if (location != null) {
                val latitude = location.latitude
                val longitude = location.longitude
                val locationUrl = "https://maps.google.com/?q=$latitude,$longitude"
                val message = "🆘 Emergency! My current location: $locationUrl"
                val phoneNumber = "919627320508"
                val whatsappUrl = "https://wa.me/$phoneNumber?text=${Uri.encode(message)}"

                val whatsappIntent = Intent(Intent.ACTION_VIEW).apply {
                    data = Uri.parse(whatsappUrl)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(whatsappIntent)
            } else {
                // Send emergency message without location
                val message = "🆘 EMERGENCY! Unable to get location. Please call me!"
                val phoneNumber = "919627320508"
                val whatsappUrl = "https://wa.me/$phoneNumber?text=${Uri.encode(message)}"

                val whatsappIntent = Intent(Intent.ACTION_VIEW).apply {
                    data = Uri.parse(whatsappUrl)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(whatsappIntent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}