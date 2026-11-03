import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_auth.dart';
import 'admin_models.dart';
import 'admin_l10n.dart' show tr;

/// Accounts, reports and the activity log of the Admin Web Console demo. All of it is fictional and
/// held in memory: there is no user directory, reporting or audit service behind the console yet, and
/// changing a record here changes nothing outside this browser tab.

enum AcctRole { shopper, agent, development, construction, architecture, interior }

enum AcctStatus { active, underReview, suspended, rejected }

enum ReportKind { listing, professional, review, ad }

enum ReportStatus { open, inReview, resolved, dismissed }

String roleName(AcctRole r) => tr(switch (r) {
  AcctRole.shopper => 'User to Shop',
  AcctRole.agent => 'Real Estate Agent',
  AcctRole.development => 'Development Company',
  AcctRole.construction => 'Construction Company',
  AcctRole.architecture => 'Building Architecture',
  AcctRole.interior => 'Interior & Exterior Design',
});

String acctStatusName(AcctStatus s) => tr(switch (s) {
  AcctStatus.active => 'Active',
  AcctStatus.underReview => 'Under review',
  AcctStatus.suspended => 'Suspended',
  AcctStatus.rejected => 'Not approved',
});

String reportKindName(ReportKind k) => tr(switch (k) {
  ReportKind.listing => 'Listing',
  ReportKind.professional => 'Professional',
  ReportKind.review => 'Review',
  ReportKind.ad => 'Sponsored ad',
});

String reportStatusName(ReportStatus s) => tr(switch (s) {
  ReportStatus.open => 'Open',
  ReportStatus.inReview => 'In review',
  ReportStatus.resolved => 'Resolved',
  ReportStatus.dismissed => 'Dismissed',
});

@immutable
class AdminAccount {
  final String id, name, email, city, note;
  final AcctRole role;
  final AcctStatus status;
  final DateTime joined;
  final int listings;
  const AdminAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.city,
    required this.role,
    required this.status,
    required this.joined,
    this.listings = 0,
    this.note = '',
  });
  AdminAccount withStatus(AcctStatus s) => AdminAccount(
    id: id,
    name: name,
    email: email,
    city: city,
    role: role,
    status: s,
    joined: joined,
    listings: listings,
    note: note,
  );
}

@immutable
class ReportNote {
  final String text, by;
  final DateTime at;
  const ReportNote(this.text, this.by, this.at);
}

@immutable
class AdminReport {
  final String id, subject, reporter, summary;
  final ReportKind kind;
  final ReportStatus status;
  final DateTime createdAt;
  final List<ReportNote> notes;
  const AdminReport({
    required this.id,
    required this.subject,
    required this.reporter,
    required this.summary,
    required this.kind,
    required this.status,
    required this.createdAt,
    this.notes = const [],
  });
  AdminReport copyWith({ReportStatus? status, List<ReportNote>? notes}) => AdminReport(
    id: id,
    subject: subject,
    reporter: reporter,
    summary: summary,
    kind: kind,
    status: status ?? this.status,
    createdAt: createdAt,
    notes: notes ?? this.notes,
  );
}

@immutable
class AuditEvent {
  final DateTime at;
  final String actor, text;
  final String? target;
  const AuditEvent(this.at, this.actor, this.text, [this.target]);
}

class AdminDirectoryState {
  final List<AdminAccount> accounts;
  final List<AdminReport> reports;
  final List<AuditEvent> audit;
  const AdminDirectoryState(this.accounts, this.reports, this.audit);
}

AdminDirectoryState seedDirectory(DateTime now) {
  DateTime d(int daysAgo, [int h = 10]) => DateTime(now.year, now.month, now.day - daysAgo, h);
  AdminAccount a(String id, String name, AcctRole r, AcctStatus s, String city, int ago, {int listings = 0, String note = ''}) =>
      AdminAccount(
        id: id,
        name: name,
        email: '${name.toLowerCase().split(' ').first}@example.test',
        city: city,
        role: r,
        status: s,
        joined: d(ago),
        listings: listings,
        note: note,
      );
  final accounts = [
    a('U1', 'Layla Demo', AcctRole.shopper, AcctStatus.active, 'Muscat', 40),
    a('U2', 'Omar Sample', AcctRole.shopper, AcctStatus.active, 'Muscat', 22),
    a('U3', 'Noor Imaginary', AcctRole.shopper, AcctStatus.suspended, 'Sohar', 75, note: tr('Suspended after repeated complaints (fictional).')),
    a('G1', 'Sami Agent Demo', AcctRole.agent, AcctStatus.active, 'Muscat', 120, listings: 7),
    a('G2', 'Rana Agent Example', AcctRole.agent, AcctStatus.underReview, 'Salalah', 3, listings: 0),
    a('G3', 'Faisal Agent Test', AcctRole.agent, AcctStatus.rejected, 'Nizwa', 15, note: tr('Licence document unreadable (fictional).')),
    a('D1', 'Horizon Developments (demo)', AcctRole.development, AcctStatus.active, 'Muscat', 200, listings: 3),
    a('D2', 'Coastline Projects (demo)', AcctRole.development, AcctStatus.underReview, 'Sur', 5),
    a('C1', 'Gulf Builders (demo)', AcctRole.construction, AcctStatus.active, 'Muscat', 90),
    a('C2', 'Al Rawda Contracting (demo)', AcctRole.construction, AcctStatus.underReview, 'Sohar', 2),
    a('A1', 'Studio Nakhal (demo)', AcctRole.architecture, AcctStatus.active, 'Muscat', 60),
    a('A2', 'Arc Atelier (demo)', AcctRole.architecture, AcctStatus.underReview, 'Muscat', 6),
    a('I1', 'Maison Interiors (demo)', AcctRole.interior, AcctStatus.active, 'Muscat', 33),
    a('I2', 'Terrace Outdoors (demo)', AcctRole.interior, AcctStatus.suspended, 'Nizwa', 48, note: tr('Portfolio images reported as copied (fictional).')),
  ];
  final reports = [
    AdminReport(id: 'R1', subject: '4-Bedroom Villa, Al Mouj', kind: ReportKind.listing, reporter: 'A shopper', summary: 'The photos look like a different property.', status: ReportStatus.open, createdAt: d(1, 14)),
    AdminReport(id: 'R2', subject: 'Terrace Outdoors (demo)', kind: ReportKind.professional, reporter: 'A shopper', summary: 'Portfolio images appear to be copied from another studio.', status: ReportStatus.inReview, createdAt: d(5), notes: [ReportNote('Account suspended while checked.', 'Demo Reviewer', d(4))]),
    AdminReport(id: 'R3', subject: 'Review of Gulf Builders (demo)', kind: ReportKind.review, reporter: 'The business', summary: 'The business says this review is about another company.', status: ReportStatus.open, createdAt: d(2)),
    AdminReport(id: 'R4', subject: 'Sponsored banner: Spring living sale', kind: ReportKind.ad, reporter: 'A shopper', summary: 'The offer on the banner does not match the destination.', status: ReportStatus.resolved, createdAt: d(9), notes: [ReportNote('Destination corrected by the sponsor.', 'Demo Senior Reviewer', d(8))]),
    AdminReport(id: 'R5', subject: 'Residential Plot, Al Khoud', kind: ReportKind.listing, reporter: 'A shopper', summary: 'Price looks far too low.', status: ReportStatus.dismissed, createdAt: d(12), notes: [ReportNote('Price matches the title deed.', 'Demo Reviewer', d(11))]),
  ];
  final audit = [
    AuditEvent(d(0, 9), 'Demo Reviewer', 'Opened report', 'R3'),
    AuditEvent(d(1, 16), 'Demo Senior Reviewer', 'Approved a listing', 'Retail Unit, Bawshar'),
    AuditEvent(d(2, 11), 'Demo Senior Reviewer', 'Requested resubmission', 'Arc Atelier (demo)'),
    AuditEvent(d(4, 15), 'Demo Reviewer', 'Suspended an account', 'Terrace Outdoors (demo)'),
    AuditEvent(d(8, 10), 'Demo Senior Reviewer', 'Resolved report', 'R4'),
    AuditEvent(d(11, 13), 'Demo Reviewer', 'Dismissed report', 'R5'),
  ];
  return AdminDirectoryState(accounts, reports, audit);
}

class AdminDirectory extends StateNotifier<AdminDirectoryState> {
  AdminDirectory(DateTime now) : super(seedDirectory(now));

  AdminAccount? account(String id) {
    for (final a in state.accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  AdminReport? report(String id) {
    for (final r in state.reports) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Writes one line to the Activity log. Other admin stores call this so one log shows every change.
  void record(String actor, String text, [String? target]) => _log(actor, text, target);

  void _log(String actor, String text, [String? target]) => state = AdminDirectoryState(
    state.accounts,
    state.reports,
    [AuditEvent(DateTime.now(), actor, text, target), ...state.audit],
  );

  void setAccountStatus(String id, AcctStatus s, String actor) {
    final a = account(id);
    if (a == null || a.status == s) return;
    state = AdminDirectoryState([for (final x in state.accounts) x.id == id ? x.withStatus(s) : x], state.reports, state.audit);
    _log(actor, 'Set account to ${acctStatusName(s).toLowerCase()}', a.name);
  }

  void setReportStatus(String id, ReportStatus s, String actor, {String? note}) {
    final r = report(id);
    if (r == null || r.status == s && (note == null || note.trim().isEmpty)) return;
    final notes = [
      if (note != null && note.trim().isNotEmpty) ReportNote(note.trim(), actor, DateTime.now()),
      ...r.notes,
    ];
    state = AdminDirectoryState(state.accounts, [for (final x in state.reports) x.id == id ? x.copyWith(status: s, notes: notes) : x], state.audit);
    if (r.status != s) _log(actor, '${reportStatusName(s)} report', id);
  }
}

final adminDirectoryProvider = StateNotifierProvider<AdminDirectory, AdminDirectoryState>(
  (ref) => AdminDirectory(DateTime.now()),
);

/// Filtering behind the accounts list (pure, so it can be tested).
List<AdminAccount> filterAccounts(List<AdminAccount> all, {String query = '', AcctRole? role, AcctStatus? status}) {
  final q = query.trim().toLowerCase();
  return [
    for (final a in all)
      if ((role == null || a.role == role) &&
          (status == null || a.status == status) &&
          (q.isEmpty || '${a.name} ${a.city} ${roleName(a.role)}'.toLowerCase().contains(q)))
        a,
  ];
}

List<AdminReport> filterReports(List<AdminReport> all, {String query = '', ReportStatus? status, ReportKind? kind}) {
  final q = query.trim().toLowerCase();
  return [
    for (final r in all)
      if ((status == null || r.status == status) &&
          (kind == null || r.kind == kind) &&
          (q.isEmpty || '${r.subject} ${r.summary}'.toLowerCase().contains(q)))
        r,
  ];
}

/// One line in the Activity log from any console screen. Resolves the signed-in admin's name.
void adminLog(WidgetRef ref, String text, [String? target]) {
  final who = ref.read(adminAuthProvider).session?.name ?? 'Admin';
  ref.read(adminDirectoryProvider.notifier).record(who, text, target);
}

String decisionVerb(Decision d) => tr(switch (d) {
  Decision.approve => 'Approved',
  Decision.requestResubmission => 'Requested changes on',
  Decision.reject => 'Rejected',
});
