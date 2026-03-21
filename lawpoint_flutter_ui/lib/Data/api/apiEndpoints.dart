class ApiEndpoints {
  static const String v1 = '/api/v1';

  // Auth
  static const String registerClient = '$v1/auth/register-client';
  static const String registerLawyer = '$v1/auth/register-lawyer';
  static const verifyEmail = '/api/v1/auth/verify-email';
  static const String login = '$v1/auth/login';
  static const String refresh = '$v1/auth/refresh';
  static const String logout = '$v1/auth/logout';
  static const String me = '$v1/users/me';

  // Lawyers
  static const String lawyers = '$v1/lawyers';
  static const String meLawyer = '$v1/lawyers/me';
  static const String myAvailability = '$v1/lawyers/me/availability';
  static String lawyerById(String id) => '$v1/lawyers/$id';
  static String lawyerAvailability(String id) => '$v1/lawyers/$id/availability';

  // Appointments
  static const String appointments = '$v1/appointments';

  // Conversations / messages
  static const String conversations = '$v1/conversations';
  static String messages(String conversationId) =>
      '$v1/conversations/$conversationId/messages';

  static const String conversationPublicKey = '$v1/conversations/keys/me';
  static String conversationE2eeKey(String conversationId) =>
      '$v1/conversations/$conversationId/e2ee-key';

  // Legal locker
  static const String lockerDocuments = '$v1/documents';
  static const String sharedDocuments = '$v1/documents/shared';
  static String lockerDocumentById(String id) => '$v1/documents/$id';
  static String shareDocument(String id) => '$v1/documents/$id/share';
  static String revokeDocument(String id) => '$v1/documents/$id/revoke';
  static String deleteDocument(String id) => '$v1/documents/$id';
  static String downloadDocument(String id) => '$v1/documents/$id/download';
  static String previewDocument(String id) => '$v1/documents/$id/preview';
  static String markDocumentReviewed(String id) =>
      '$v1/documents/$id/mark-reviewed';

  static String downloadDocumentToken(String id) =>
      '$v1/documents/$id/download-token';

  static String downloadDocumentSigned(String id) =>
      '$v1/documents/$id/download-by-token';

  // Cases
  static const String cases = '$v1/cases';
  static String caseUpdates(String caseId) => '$v1/cases/$caseId/updates';

  // Knowledge hub
  static const String knowledgeArticles = '$v1/knowledge';

  // Video
  static const String videoToken = '$v1/video/token';

  // Payments
  static const String payments = '$v1/payments';
  static const String paymentCheckoutSession = '$payments/checkout-session';

  // Notifications
  static const notifications = '$v1/notifications';
}
