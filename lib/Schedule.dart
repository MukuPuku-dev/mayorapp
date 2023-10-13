import 'dart:io';


class Schedule {
  final DateTime time;
  final String agenda;
  final String applicant;
  final String address;
  final String remarks;
  bool attended;
  String? imageUrl; // Add the image URL property
  String? uploader;
  String? editor;
  String? id;
  String? additionalImages;

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

  void setAttended(bool isAttended) {
    attended = isAttended;
  }
  void setImageURL(String url) {
    imageUrl = url;
  }
  void setUploader(String uploaderName){
    uploader= uploaderName;
  }
  void setEditor(String editorName){
    editor= editorName;
  }

}
