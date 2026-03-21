import '../../Models/lawyer.dart';
import '../../Models/caseItem.dart';
import '../../Models/caseUpdate.dart';
import '../../Models/knowledgeArticle.dart';
import '../../Models/document.dart';
import '../../Models/conversation.dart';
import '../../Models/message.dart';
import '../../Models/notification_item.dart';

class DummyData {
  static final List<Lawyer> lawyers = [
    const Lawyer(
      id: 'l1',
      fullName: 'Adv. Nimal Perera',
      specialisations: ['Family Law', 'Property'],
      languages: ['Sinhala', 'English'],
      district: 'Colombo',
      verified: true,
      feeLkr: 5000,
      bio: '10+ years experience in family and property matters.',
    ),
    const Lawyer(
      id: 'l2',
      fullName: 'Adv. Priya Rajendran',
      specialisations: ['Contracts', 'Civil'],
      languages: ['Tamil', 'English'],
      district: 'Jaffna',
      verified: true,
      feeLkr: 4500,
      bio: 'Civil and contract dispute support.',
    ),
  ];

  static final List<CaseItem> cases = [
    CaseItem(
      id: 'c1',
      title: 'Property boundary dispute',
      description: 'Initial review completed.',
      status: 'OPEN',
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      clientId: 'u_client',
      lawyerId: 'l1',
    ),
    CaseItem(
      id: 'c2',
      title: 'Divorce consultation',
      description: 'Documents shared and under review.',
      status: 'IN_PROGRESS',
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      updatedAt: DateTime.now().subtract(const Duration(days: 4)),
      clientId: 'u_client',
      lawyerId: 'l2',
    ),
  ];

  static final Map<String, List<CaseUpdate>> caseUpdates = {
    'c1': [
      CaseUpdate(
        id: 'cu1',
        caseId: 'c1',
        title: 'Initial review completed',
        description: 'Reviewed boundary sketch and deed copy.',
        postedById: 'u_lawyer_1',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ],
    'c2': [
      CaseUpdate(
        id: 'cu2',
        caseId: 'c2',
        title: 'Consultation summary added',
        description: 'Prepared next steps for the client.',
        postedById: 'u_lawyer_2',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ],
  };

  static final List<DocumentItem> documents = [
    DocumentItem(
      id: 'd1',
      fileName: 'LandDeed.pdf',
      fileType: 'application/pdf',
      uploadedAt: DateTime.now().subtract(const Duration(days: 5)),
      shared: true,
      checksum: 'mock_checksum_1',
      classification: 'NORMAL',
    ),
    DocumentItem(
      id: 'd2',
      fileName: 'NIC_Front.jpg',
      fileType: 'image/jpeg',
      uploadedAt: DateTime.now().subtract(const Duration(days: 2)),
      shared: false,
      checksum: 'mock_checksum_2',
      classification: 'SECRET',
      secretCategory: 'sri_nic',
      redactionStatus: 'READY',
      hasRedactedVersion: true,
      requiresPreviewBeforeShare: true,
      reviewedForShare: false,
    ),
  ];

  static final List<KnowledgeArticle> articles = [
    KnowledgeArticle(
      id: 'kh1',
      topic: 'Family Law',
      language: 'en',
      title: 'Basics of Divorce Procedures in Sri Lanka',
      content: 'Starter demo article for knowledge hub.',
      publishedAt: DateTime.now().subtract(const Duration(days: 40)),
    ),
    KnowledgeArticle(
      id: 'kh2',
      topic: 'Property',
      language: 'si',
      title: 'ඉඩම් ඔප්පු සහ අයිතිය පරීක්ෂා කිරීම',
      content: 'දේපළ සම්බන්ධ ආරම්භක දැනුම් ලිපිය.',
      publishedAt: DateTime.now().subtract(const Duration(days: 12)),
    ),
    KnowledgeArticle(
      id: 'kh3',
      topic: 'Contracts',
      language: 'ta',
      title: 'ஒப்பந்தத்தில் கையெழுத்திடும் முன் பார்க்க வேண்டியவை',
      content: 'சட்ட அறிவு மையத்திற்கான மாதிரி கட்டுரை.',
      publishedAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
  ];

  static final List<Conversation> conversations = [
    Conversation(
      id: 'conv1',
      clientId: 'u_client',
      lawyerId: 'l1',
      title: 'Adv. Nimal Perera',
      lastMessagePreview: 'Please upload the deed copy.',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
    ),
  ];

  static final Map<String, List<MessageItem>> messages = {
    'conv1': [
      MessageItem(
        id: 'm1',
        conversationId: 'conv1',
        senderId: 'l1',
        content: 'Hello. Please upload the deed copy.',
        sentAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      MessageItem(
        id: 'm2',
        conversationId: 'conv1',
        senderId: 'u_client',
        content: 'Sure, I will upload it now.',
        sentAt: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
    ],
  };

  static final List<NotificationItem> notifications = [
    NotificationItem(
      id: 'n1',
      userId: 'u_client',
      title: 'Appointment booked',
      body: 'Your appointment has been scheduled successfully.',
      type: 'appointment.booked',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      readAt: null,
      data: {
        'appointmentId': 'a1',
        'screen': 'appointment',
      },
    ),
    NotificationItem(
      id: 'n2',
      userId: 'u_client',
      title: 'New case update',
      body: 'Your lawyer posted a new case update.',
      type: 'case.update_posted',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      readAt: null,
      data: {
        'caseId': 'c1',
        'screen': 'case',
      },
    ),
  ];
}
