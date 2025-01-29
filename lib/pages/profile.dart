import 'package:flutter/material.dart';
import 'package:raksha/Home/home.dart';
import 'package:raksha/pages/loginpage.dart';
import 'package:raksha/services/authservice.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Placeholder data for profile
  String name = "John Doe";
  String email = "john.doe@example.com";
  String contactNumber = "123-456-7890";
  String emergencyContact = "987-654-3210";
  String profilePic = "assets/images/avtar.png"; // Placeholder for profile picture

  // Controllers to handle text input for updates
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController contactController = TextEditingController();
  TextEditingController emergencyController = TextEditingController();

  final AuthService _authService = AuthService(); // Instance of AuthService

  @override
  void initState() {
    super.initState();
    // Set the initial values for the text controllers
    nameController.text = name;
    emailController.text = email;
    contactController.text = contactNumber;
    emergencyController.text = emergencyContact;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Profile"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Back icon
          onPressed: () {
            Navigator.pop(context); // Simply pop the current screen
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile picture
              CircleAvatar(
                radius: 60,
                backgroundImage: AssetImage(profilePic),
              ),
              const SizedBox(height: 20),

              // Name
              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              // Email
              ListTile(
                title: const Text("Email"),
                subtitle: Text(email),
                trailing: const Icon(Icons.edit),
                onTap: () {
                  _showEditDialog("Email", emailController, (newValue) {
                    setState(() {
                      email = newValue;
                    });
                  });
                },
              ),

              const SizedBox(height: 10),

              // Contact Number
              ListTile(
                title: const Text("Contact Number"),
                subtitle: Text(contactNumber),
                trailing: const Icon(Icons.edit),
                onTap: () {
                  _showEditDialog("Contact Number", contactController, (newValue) {
                    setState(() {
                      contactNumber = newValue;
                    });
                  });
                },
              ),

              const SizedBox(height: 10),

              // Emergency Contact Number
              ListTile(
                title: const Text("Emergency Contact"),
                subtitle: Text(emergencyContact),
                trailing: const Icon(Icons.edit),
                onTap: () {
                  _showEditDialog("Emergency Contact", emergencyController, (newValue) {
                    setState(() {
                      emergencyContact = newValue;
                    });
                  });
                },
              ),

              const SizedBox(height: 30),

              // Logout Button
              ElevatedButton(
                onPressed: () async {
                  await _logout(); // Call the logout function
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                ),
                child: const Text(
                  "Logout",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Function to show an edit dialog for changing values
  void _showEditDialog(String field, TextEditingController controller, Function(String) onSave) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Edit $field"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: "Enter new $field",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                onSave(controller.text); // Save the new value
                Navigator.pop(context); // Close the dialog
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // Logout function
  Future<void> _logout() async {
    try {
      await _authService.signOut(); // Call the AuthService signOut function

      // Clear any local state or session data, if any
      // Example: SharedPreferences, localStorage, etc.

      // Navigate to the LoginPage after sign out
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) =>  LoginPage()), // Ensure LoginPage is correctly initialized
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error during sign out: $e"),
        ),
      );
    }
  }

}
