// import 'dart:io'; // Unused import

/// Represents a schedule item.
class Schedule {
  final DateTime time; // Date and time of the schedule
  final String agenda; // Main agenda or topic of the schedule
  final String applicant; // Person or entity who applied for/requested the schedule
  final String address; // Location or address for the schedule
  final String remarks; // Additional remarks or notes
  bool attended; // Status indicating if the schedule was attended
  String? imageUrl; // URL of the primary image associated with the schedule
  String? uploader; // Name or identifier of the user who uploaded the schedule
  String? editor; // Name or identifier of the user who last edited the schedule
  String? id; // Firestore document ID for this schedule
  String? additionalImages; // Comma-separated string of URLs for additional images

  /// Constructs a [Schedule] object.
  ///
  /// All fields related to schedule details are required.
  /// [attended] defaults to false.
  /// [imageUrl], [uploader], [editor], [id], and [additionalImages] are optional.
  Schedule({
    required this.time,
    required this.agenda,
    required this.applicant,
    required this.address,
    required this.remarks,
    this.attended = false,
    this.imageUrl,
    this.uploader,
    this.editor,
    this.id,
    this.additionalImages,
  });

  /// Sets the attendance status of the schedule.
  void setAttended(bool isAttended) {
    attended = isAttended;
  }

  /// Sets the primary image URL for the schedule.
  void setImageURL(String url) {
    imageUrl = url;
  }

  /// Sets the name of the uploader for this schedule.
  void setUploader(String uploaderName) {
    uploader = uploaderName;
  }

  /// Sets the name of the editor for this schedule.
  void setEditor(String editorName) {
    editor = editorName;
  }
}
