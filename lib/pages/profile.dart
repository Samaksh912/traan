import 'package:flutter/material.dart';
 // Import UserModel
import 'package:raksha/services/authservice.dart';

import '../models/usermodel.dart';
import '../services/firestoreservice.dart';
import 'loginpage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Initial user data
  UserModel user = UserModel(
    name: "John Doe",
    email: "john.doe@example.com",
    contactNumber: "123-456-7890",
    emergencyContact1: "987-654-3210",
    emergencyContact2: "112-233-4455",
  );

  // Controllers for the text fields
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController contactController = TextEditingController();
  TextEditingController emergencyController1 = TextEditingController();
  TextEditingController emergencyController2 = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    nameController.text = user.name;
    emailController.text = user.email;
    contactController.text = user.contactNumber;
    emergencyController1.text = user.emergencyContact1;
    emergencyController2.text = user.emergencyContact2;

    // Fetch user data from Firestore if available
    _fetchUserData();
  }

  // Fetch user data from Firestore and update the fields
  Future<void> _fetchUserData() async {
    final fetchedUser = await _firestoreService.getUserData();
    if (fetchedUser != null) {
      setState(() {
        user = fetchedUser;
        nameController.text = user.name;
        emailController.text = user.email;
        contactController.text = user.contactNumber;
        emergencyController1.text = user.emergencyContact1;
        emergencyController2.text = user.emergencyContact2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black87,
        centerTitle: true,
        title: const Text("Profile",style: TextStyle(color: Colors.white) ,),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,color: Colors.white,),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile picture can be removed if not needed

              const SizedBox(height: 20),

              // Editable fields
              _buildEditableField("Name", nameController),
              _buildEditableField("Email", emailController),

              _buildEditableField("Emergency Contact 1 (for sos)", emergencyController1),
              _buildEditableField("Emergency Contact 2 (for emergency number)", emergencyController2),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: () async {
                  // Save the updated user data
                  final updatedUser = UserModel(
                    name: nameController.text,
                    email: emailController.text,
                    contactNumber: contactController.text,
                    emergencyContact1: emergencyController1.text,
                    emergencyContact2: emergencyController2.text,
                  );
                  await _firestoreService.saveUserData(updatedUser);
                  // Show a SnackBar after saving
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile changes saved successfully!'),
                      duration: Duration(seconds: 2),
                    ),
                  );


                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black54,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                ),
                child: const Text(
                  "Save Changes",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 15,),
              ElevatedButton(
                onPressed: () async {
                  await _logout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
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

  // Function to create editable fields for the profile
  Widget _buildEditableField(String fieldName, TextEditingController controller) {
    return ListTile(
      title: Text(fieldName),
      subtitle: Text(controller.text),
      trailing: const Icon(Icons.edit),
      onTap: () {
        _showEditDialog(fieldName, controller);
      },
    );
  }

  void _showEditDialog(String field, TextEditingController controller) {
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
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  // Update the user data with the new value
                  if (field == "Name") {
                    user.name = controller.text;
                  } else if (field == "Email") {
                    user.email = controller.text;
                  } else if (field == "Contact Number") {
                    user.contactNumber = controller.text;
                  } else if (field == "Emergency Contact 1") {
                    user.emergencyContact1 = controller.text;
                  } else if (field == "Emergency Contact 2") {
                    user.emergencyContact2 = controller.text;
                  }
                });
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
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
