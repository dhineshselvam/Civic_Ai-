import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton-based API service so token is shared across all screens
class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService({String? baseUrl}) => _instance;
  ApiService._internal();

  final String _baseUrl = kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
  String? _token;

  String get baseUrl => _baseUrl;
  bool get isAuthenticated => _token != null;

  void setToken(String token) {
    _token = token;
    SharedPreferences.getInstance().then((p) => p.setString('auth_token', token));
  }

  void clearToken() {
    _token = null;
    SharedPreferences.getInstance().then((p) => p.remove('auth_token'));
  }

  /// Try to restore a saved session from local storage (survives page refresh)
  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('auth_token');
    if (saved != null) { _token = saved; return true; }
    return false;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Parses API error body into a friendly message
  String _parseError(String body, int statusCode) {
    try {
      final Map<String, dynamic> data = jsonDecode(body);
      // Handle DRF error formats
      if (data.containsKey('error')) return data['error'] as String;
      if (data.containsKey('detail')) return data['detail'] as String;
      if (data.containsKey('non_field_errors')) {
        final errs = data['non_field_errors'];
        if (errs is List) return errs.join(', ');
      }
      // Flatten field-level errors
      final List<String> msgs = [];
      data.forEach((key, value) {
        if (value is List) {
          msgs.add('${_capitalize(key)}: ${value.join(", ")}');
        } else {
          msgs.add('${_capitalize(key)}: $value');
        }
      });
      if (msgs.isNotEmpty) return msgs.join('\n');
    } catch (_) {}
    switch (statusCode) {
      case 400: return 'Invalid data. Please check your inputs.';
      case 401: return 'Incorrect username or password.';
      case 403: return 'You do not have permission to perform this action.';
      case 404: return 'The requested resource was not found.';
      case 500: return 'Server error. Please try again later.';
      default: return 'Something went wrong (code $statusCode).';
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

  /// Traditional Registration
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? phone,
    String role = 'CITIZEN',
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/users/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password, 'phone_number': phone, 'role': role}),
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final access = data['access'] as String?;
      if (access != null) {
        setToken(access);
      }
      return data;
    }
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }

  /// Password-based Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/users/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final access = data['access'] as String?;
      if (access != null) {
        setToken(access);
      }
      return data;
    }
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }

  /// Admin-only: Register a new Crew Member
  Future<Map<String, dynamic>> registerCrew({
    required String username,
    required String email,
    required String password,
    required String department,
    String? phone,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/users/register-crew/'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'phone_number': phone,
        'role': 'CREW',
        'department': department,
      }),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }

  /// Logout (clears local token)
  void logout() => clearToken();

  /// Request Password Reset
  Future<void> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/users/password-reset/request/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode != 200) {
      throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
    }
  }

  /// Confirm Password Reset
  Future<void> confirmPasswordReset(String email, String token, String newPassword) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/users/password-reset/confirm/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'token': token, 'new_password': newPassword}),
    );
    if (response.statusCode != 200) {
      throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
    }
  }

  /// Fetch user notifications
  Future<List<dynamic>> getNotifications() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/users/notifications/'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body) as List<dynamic>;
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }

  /// Mark all notifications as read
  Future<void> markNotificationsRead() async {
    final response = await http.post(Uri.parse('$_baseUrl/api/users/notifications/'), headers: _headers);
    if (response.statusCode != 200) {
      throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
    }
  }

  /// Fetch user profile (includes trust score)
  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/users/profile/'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }

  /// Submit a civic report.
  Future<ReportSubmitResponse> submitReport({
    required dynamic imageBytes,
    required String description,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    String imageFilename = 'image.jpg',
    String address = '',
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/report-issue/'));

    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';

    final bytes = imageBytes is Uint8List ? imageBytes : Uint8List.fromList(imageBytes as List<int>);
    request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: imageFilename));
    request.fields['description'] = description;
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();
    request.fields['timestamp'] = timestamp.toIso8601String();
    request.fields['address'] = address;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ReportSubmitResponse.fromJson(response.body);
    }
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }

  /// Fetch complaints
  Future<List<Complaint>> getComplaints({String? status, bool? assignedToMe, bool? allSubmissions}) async {
    String url = '$_baseUrl/api/complaints/';
    final params = <String>[];
    if (status != null) params.add('status=$status');
    if (assignedToMe == true) params.add('assigned_to_me=true');
    if (allSubmissions == true) params.add('all_submissions=true');
    if (params.isNotEmpty) url += '?${params.join('&')}';

    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((e) => Complaint.fromMap(e)).toList();
    }
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }

  /// Fetch a single complaint by ID
  Future<Complaint> getComplaint(int id) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/complaints/$id/'), headers: _headers);
    if (response.statusCode == 200) {
      return Complaint.fromMap(jsonDecode(response.body));
    }
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }

  Future<List<Complaint>> getCrewTasks() => getComplaints(assignedToMe: true);

  /// Get Admin Dashboard Stats
  Future<Map<String, dynamic>> getAdminStats() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/dashboard/stats/'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }

  /// Get High Priority Unresolved Issues
  Future<List<Complaint>> getHighPriorityIssues() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/high-priority/'), headers: _headers);
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((e) => Complaint.fromMap(e)).toList();
    }
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }

  /// List all teams (Admin only)
  Future<List<Map<String, dynamic>>> listTeams() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/users/teams/'), headers: _headers);
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }

  /// List all field crew members (Admin only)
  Future<List<Map<String, dynamic>>> listCrewMembers() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/users/crew-list/'), headers: _headers);
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }

  /// Update a member's team (Admin only)
  Future<void> updateMemberTeam(int teamId, int userId, String action) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/users/teams/$teamId/members/'),
      headers: _headers,
      body: jsonEncode({'user_id': userId, 'action': action}),
    );
    if (response.statusCode != 200) {
      throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
    }
  }

  /// Assign a complaint to a crew member (Admin only)
  Future<void> assignComplaint(int id, String crewUsername) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/complaints/$id/assign/'),
      headers: _headers,
      body: jsonEncode({'assigned_to': crewUsername}),
    );
    if (response.statusCode != 200) {
      throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
    }
  }

  /// Auto-assign best crew (Admin only)
  Future<String> autoAssignComplaint(int id) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/complaints/$id/auto-assign/'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _parseError(response.body, response.statusCode),
      );
    }
    final data = jsonDecode(response.body);
    return data['message'] ?? 'Successfully assigned';
  }

  /// Manage individual crew assignment (Admin only)
  /// action: 'add' | 'remove' | 'swap'
  Future<void> manageCrewAssignment({
    required int complaintId,
    required String action,
    int? userId,
    int? swapWithId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/complaints/$complaintId/manage-crew/'),
      headers: _headers,
      body: jsonEncode({
        'action': action,
        'user_id': userId,
        'swap_with_id': swapWithId,
      }),
    );
    if (response.statusCode != 200) {
      throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
    }
  }

  /// Update complaint status (Crew/Admin)
  Future<void> updateComplaintStatus(int id, String newStatus) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/complaints/$id/assign/'),
      headers: _headers,
      body: jsonEncode({'status': newStatus}),
    );
    if (response.statusCode != 200) {
      throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
    }
  }

  /// Manually edit complaint metadata (category, priority)
  Future<void> editComplaint(int id, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/api/complaints/$id/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
    }
  }

  /// Submit feedback for a resolved issue
  Future<void> submitFeedback(int id, int rating, String feedback) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/api/complaints/$id/feedback/'),
      headers: _headers,
      body: jsonEncode({'rating': rating, 'feedback': feedback}),
    );
    if (response.statusCode != 200) {
      throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
    }
  }

  /// Get real analytics data for City Analytics screen
  Future<Map<String, dynamic>> getAnalytics() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/analytics/'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }

  /// List crew members (Admin only), optionally filtered by department
  Future<List<Map<String, dynamic>>> listCrew({String? department}) async {
    var url = '$_baseUrl/api/crew/';
    if (department != null) url += '?department=$department';
    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    throw ApiException(statusCode: response.statusCode, message: _parseError(response.body, response.statusCode));
  }
}

/// Domain model for a Civic Complaint.
class Complaint {
  const Complaint({
    required this.id,
    required this.image,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.predicted_category,
    required this.createdAt,
    required this.priorityScore,
    required this.priorityLabel,
    this.imageUrl,
    this.address,
    this.assignedCrew,
    this.assignedTeams,
    this.assignedUsers,
    this.rating,
    this.feedback,
    this.upvoteCount,
    this.reports,
    this.isOriginal = false,
    this.department,
  });

  factory Complaint.fromMap(Map<String, dynamic> map) {
    return Complaint(
      id: map['id'] as int,
      image: map['image'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      description: map['description'] as String? ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      status: map['status'] as String? ?? 'Reported',
      predicted_category: map['predicted_category'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      address: map['address'] as String?,
      assignedCrew: map['assigned_crew'] as int?,
      assignedTeams: (map['assigned_teams'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList(),
      assignedUsers: (map['assigned_users'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList(),
      rating: map['rating'] as int?,
      feedback: map['feedback'] as String?,
      priorityScore: map['priority_score'] as int? ?? 50,
      priorityLabel: map['priority_label'] as String? ?? 'Medium',
      upvoteCount: map['upvote_count'] as int?,
      reports: (map['reports'] as List<dynamic>?)?.map((e) => UserReport.fromMap(e)).toList(),
      isOriginal: map['is_original'] as bool? ?? false,
      department: map['department'] as String?,
    );
  }

  final int id;
  final String image;
  final String? imageUrl;   // Full absolute URL from backend
  final String description;
  final double latitude;
  final double longitude;
  final String status;
  final String predicted_category;
  final DateTime createdAt;
  final String? address;
  final int? assignedCrew;
  final List<Map<String, dynamic>>? assignedTeams;
  final List<Map<String, dynamic>>? assignedUsers;
  final int? rating;
  final String? feedback;
  final int priorityScore;
  final String priorityLabel;
  final int? upvoteCount;
  final List<UserReport>? reports;
  final bool isOriginal;
  final String? department;
}

/// Represents an individual citizen submission (UserReport layer)
class UserReport {
  UserReport({
    required this.id,
    required this.image,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.predictedCategory,
    required this.createdAt,
    required this.priorityScore,
    required this.priorityLabel,
    required this.isOriginal,
    this.imageUrl,
    this.address,
    this.username,
    this.upvoteCount,
    this.assignedTeams,
    this.assignedUsers,
  });

  factory UserReport.fromMap(Map<String, dynamic> map) {
    return UserReport(
      id: map['id'] as int,
      image: map['image'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      description: map['description'] as String? ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      status: map['status'] as String? ?? 'Reported',
      predictedCategory: map['predicted_category'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      address: map['address'] as String?,
      username: map['username'] as String?,
      isOriginal: map['is_original'] as bool? ?? false,
      priorityScore: map['priority_score'] as int? ?? 50,
      priorityLabel: map['priority_label'] as String? ?? 'Medium',
      upvoteCount: map['upvote_count'] as int?,
      assignedTeams: (map['assigned_teams'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList(),
      assignedUsers: (map['assigned_users'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList(),
    );
  }

  final int id;
  final String image;
  final String? imageUrl;
  final String description;
  final double latitude;
  final double longitude;
  final String status;
  final String predictedCategory;
  final DateTime createdAt;
  final String? address;
  final String? username;
  final bool isOriginal;
  final int priorityScore;
  final String priorityLabel;
  final int? upvoteCount;
  final List<Map<String, dynamic>>? assignedTeams;
  final List<Map<String, dynamic>>? assignedUsers;
}

/// Response from POST /api/report-issue/
class ReportSubmitResponse {
  const ReportSubmitResponse({
    required this.message,
    required this.predictedCategory,
    required this.complaintId,
    required this.priorityScore,
    required this.priorityLabel,
  });

  factory ReportSubmitResponse.fromJson(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return ReportSubmitResponse(
      message: map['message'] as String? ?? 'Success',
      predictedCategory: map['predicted_category'] as String? ?? 'Unknown',
      complaintId: map['complaint_id'] as int? ?? 0,
      priorityScore: map['priority_score'] as int? ?? 50,
      priorityLabel: map['priority_label'] as String? ?? 'Medium',
    );
  }

  final String message;
  final String predictedCategory;
  final int complaintId;
  final int priorityScore;
  final String priorityLabel;
}

class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.message});
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}