import 'package:flutter/material.dart';

/// Every user-visible string of the property-viewing flow (screens 39-51).
/// ARABIC IS DRAFT COPY and needs native / business review before launch.
class ViewingStrings {
  final bool ar;
  const ViewingStrings._(this.ar);
  @visibleForTesting
  const ViewingStrings.forTest(this.ar);
  static ViewingStrings of(BuildContext c) =>
      ViewingStrings._(Localizations.localeOf(c).languageCode == 'ar');

  String t(String key, [Map<String, String> args = const {}]) {
    final e = _s[key];
    assert(e != null, 'Missing string: $key');
    var out = e == null ? key : (ar ? e.$2 : e.$1);
    args.forEach((k, v) => out = out.replaceAll('{$k}', v));
    return out;
  }

  static Iterable<String> get keys => _s.keys;
}

const Map<String, (String, String)> _s = {
  'vw.back': ('Back', 'رجوع'),
  'vw.retry': ('Try again', 'إعادة المحاولة'),
  'vw.continue': ('Continue', 'متابعة'),
  'vw.loadError': (
    'We could not load this. Check your connection and try again.',
    'تعذّر التحميل. تحقق من اتصالك وحاول مرة أخرى.',
  ),
  'vw.notFound': (
    'This viewing could not be found.',
    'تعذّر العثور على هذه المعاينة.',
  ),
  'vw.beds': ('{n} beds', '{n} غرف'),
  'vw.bed1': ('1 bed', 'غرفة واحدة'),
  'vw.area': ('{n} m²', '{n} م²'),
  'vw.tx.buy': ('For sale', 'للبيع'),
  'vw.tx.rent': ('For rent', 'للإيجار'),
  'vw.tx.lease': ('For lease', 'للتأجير'),
  'vw.property': ('Property', 'العقار'),
  // availability (39)
  'vw.schedule.title': ('Schedule a Viewing', 'جدولة معاينة'),
  'vw.short.cancel': ('Cancel', 'إلغاء'),
  'vw.short.reschedule': ('New time', 'وقت آخر'),
  'vw.short.tryAnotherSlot': ('New time', 'وقت آخر'),
  'vw.short.scheduleAnother': ('Book again', 'احجز مجدداً'),
  'vw.short.browseSimilar': ('Similar', 'مشابهة'),
  'vw.short.writeReview': ('Rate', 'قيّم'),
  'vw.short.backToProperty': ('View property', 'العقار'),
  'vw.short.viewMyViewings': ('My viewings', 'معايناتي'),
  'vw.useTime': ('Use {t}', 'اختيار {t}'),
  'vw.send.short': ('Send request', 'إرسال الطلب'),
  'vw.changeTime.short': ('Change', 'تغيير'),
  'vw.selectNew.short': ('New time', 'وقت جديد'),
  'vw.stepOf': ('Step {n} of {t}', 'الخطوة {n} من {t}'),
  'vw.stepName1': ('Date', 'التاريخ'),
  'vw.stepName2': ('Time', 'الوقت'),
  'vw.stepName3': ('Review', 'المراجعة'),
  'vw.s1.title': ('Choose a date', 'اختر التاريخ'),
  'vw.s1.sub': ('Pick the day you would like to visit. You will choose a time next.', 'اختر اليوم الذي تود الزيارة فيه. ستختار الوقت في الخطوة التالية.'),
  'vw.s1.hint': ('Days with no free times are dimmed.', 'الأيام التي لا تتوفر فيها أوقات تظهر باهتة.'),
  'vw.s1.cta': ('Choose a time', 'اختيار الوقت'),
  'vw.s1.note': ('Nothing is sent yet. You can review the request before it goes to the host.', 'لن يُرسل شيء الآن. يمكنك مراجعة الطلب قبل إرساله إلى المضيف.'),
  'vw.s1.open': ('{n} times open on {d}', '{n} أوقات متاحة يوم {d}'),
  'vw.selectedDate': ('Selected date', 'التاريخ المحدد'),
  'vw.pickDate': ('Choose a date to continue', 'اختر تاريخاً للمتابعة'),
  'vw.s2.title': ('Choose a time', 'اختر الوقت'),
  'vw.s2.sub': ('Pick a start time on {d}.', 'اختر وقت البدء يوم {d}.'),
  'vw.s2.sub0': ('Pick a start time for your visit.', 'اختر وقت بدء الزيارة.'),
  'vw.s2.cta': ('Review request', 'مراجعة الطلب'),
  'vw.s2.change': ('Change date', 'تغيير التاريخ'),
  'vw.chooseDate': ('Choose a date', 'اختر التاريخ'),
  'vw.chooseDate.sub': (
    'Select a date to see available viewing times.',
    'اختر تاريخاً لعرض أوقات المعاينة المتاحة.',
  ),
  'vw.times': ('Available times', 'الأوقات المتاحة'),
  'vw.times.sub': (
    'Select a time slot for your viewing.',
    'اختر وقتاً لمعاينتك.',
  ),
  'vw.zone': ('Time zone: {city} ({zone})', 'المنطقة الزمنية: {city} ({zone})'),
  'vw.legend.available': ('Available', 'متاح'),
  'vw.legend.limited': ('Limited', 'محدود'),
  'vw.legend.unavailable': ('Unavailable', 'غير متاح'),
  'vw.period.morning': ('Morning', 'صباحاً'),
  'vw.period.afternoon': ('Afternoon', 'بعد الظهر'),
  'vw.period.evening': ('Evening', 'مساءً'),
  'vw.selected': ('Selected', 'المحدد'),
  'vw.selectedSlot': ('Selected slot', 'الموعد المحدد'),
  'vw.pick': ('Choose a date and time', 'اختر التاريخ والوقت'),
  'vw.pickTime': ('Now choose a time', 'اختر الآن وقتاً'),
  'vw.hostConfirms': (
    'The host will confirm your viewing request.',
    'سيؤكد المضيف طلب المعاينة.',
  ),
  'vw.noTimes': (
    'No viewing times available for this day.',
    'لا توجد أوقات معاينة متاحة في هذا اليوم.',
  ),
  'vw.noTimes.action': ('Choose another day', 'اختر يوماً آخر'),
  'vw.noDays': (
    'There are no open viewing days right now. Please check back soon.',
    'لا توجد أيام معاينة متاحة حالياً. يرجى المراجعة لاحقاً.',
  ),
  'vw.availError': (
    'Could not load viewing availability.',
    'تعذّر تحميل مواعيد المعاينة المتاحة.',
  ),
  // slot (40)
  'vw.slot.title': ('Select Viewing Slot', 'اختيار موعد المعاينة'),
  'vw.slot.sub': (
    'Choose a convenient date and time to visit this property.',
    'اختر تاريخاً ووقتاً مناسباً لزيارة هذا العقار.',
  ),
  'vw.step1': ('1. Select a date', '١. اختر التاريخ'),
  'vw.step2': ('2. Select a time slot', '٢. اختر وقتاً'),
  'vw.slots': ('{n} slots', '{n} مواعيد'),
  'vw.slot1': ('1 slot', 'موعد واحد'),
  'vw.reviewFirst': (
    'You will review and confirm before sending the request.',
    'ستراجع طلبك وتؤكده قبل إرساله.',
  ),
  'vw.prevWeek': ('Earlier dates', 'تواريخ أسبق'),
  'vw.nextWeek': ('Later dates', 'تواريخ أبعد'),
  // review (41)
  'vw.review.title': ('Viewing Request Review', 'مراجعة طلب المعاينة'),
  'vw.review.sub': (
    'Please confirm your details before sending the request.',
    'يرجى تأكيد التفاصيل قبل إرسال الطلب.',
  ),
  'vw.yourViewing': ('Your selected viewing', 'معاينتك المحددة'),
  'vw.date': ('Date', 'التاريخ'),
  'vw.time': ('Time', 'الوقت'),
  'vw.duration': ('Duration', 'المدة'),
  'vw.minutes': ('{n} minutes', '{n} دقيقة'),
  'vw.meeting': ('Meeting location', 'موقع اللقاء'),
  'vw.meeting.pending': (
    'The exact meeting point is shared after the host confirms your request.',
    'تتم مشاركة نقطة اللقاء بعد تأكيد المضيف لطلبك.',
  ),
  'vw.meeting.confirmed': (
    'The host provides the exact meeting point.',
    'يحدد المضيف نقطة اللقاء بدقة.',
  ),
  'vw.host': ('Host', 'المضيف'),
  'vw.contact.note': (
    'Contact details are shared once the host confirms.',
    'تتم مشاركة بيانات التواصل بعد تأكيد المضيف.',
  ),
  'vw.verifiedAgent': ('Verified agent', 'وسيط موثّق'),
  'vw.reviewsCount': ('{n} reviews', '{n} تقييماً'),
  'vw.send': ('Send viewing request', 'إرسال طلب المعاينة'),
  'vw.sending': ('Sending your request', 'جارٍ إرسال طلبك'),
  'vw.changeTime': ('Change time', 'تغيير الوقت'),
  'vw.sendError': (
    'Your request could not be sent. Your selected time is saved, so you can try again.',
    'تعذّر إرسال طلبك. وقتك المحدد محفوظ، يمكنك المحاولة مرة أخرى.',
  ),
  // requested (42)
  'vw.requested.title': ('Viewing request sent', 'تم إرسال طلب المعاينة'),
  'vw.requested.sub': ('Your request is with the host.', 'طلبك لدى المضيف.'),
  'vw.next': ('What happens next', 'ما الخطوة التالية'),
  'vw.next.requested': (
    'The host will review your request. We will notify you when the host responds.',
    'سيراجع المضيف طلبك. سنُعلمك عند ردّ المضيف.',
  ),
  'vw.stage.requestSent': ('Request sent', 'تم الإرسال'),
  'vw.stage.underReview': ('Under review', 'قيد المراجعة'),
  'vw.stage.confirmed': ('Confirmed', 'مؤكد'),
  'vw.stage.visit': ('Visit', 'الزيارة'),
  'vw.stage.completed': ('Completed', 'مكتمل'),
  'vw.timeline': ('Viewing progress', 'تقدّم المعاينة'),
  'vw.timeline.step': (
    'Step {n} of {total}: {name}',
    'الخطوة {n} من {total}: {name}',
  ),
  'vw.backToProperty': ('Back to property', 'العودة إلى العقار'),
  'vw.viewMy': ('View my viewings', 'عرض معايناتي'),
  'vw.viewDetails': ('View viewing details', 'عرض تفاصيل المعاينة'),
  // confirmed (43)
  'vw.confirmed.title': ('Viewing confirmed', 'تم تأكيد المعاينة'),
  'vw.confirmed.sub': (
    'The host accepted your viewing request.',
    'قبل المضيف طلب المعاينة.',
  ),
  // declined (44)
  'vw.declined.title': ('Viewing declined', 'تم رفض المعاينة'),
  'vw.declined.sub': (
    'The host is unable to accommodate this viewing request at this time.',
    'لا يستطيع المضيف تلبية طلب المعاينة هذا في الوقت الحالي.',
  ),
  'vw.declined.reason': ('Note from the host', 'ملاحظة من المضيف'),
  'vw.requestedSlot': ('Your requested slot', 'الموعد الذي طلبته'),
  'vw.whatYouCanDo': ('What you can do', 'ما يمكنك فعله'),
  'vw.declined.tip': (
    'Try another available slot, or browse similar properties.',
    'جرّب موعداً آخر متاحاً، أو تصفّح عقارات مشابهة.',
  ),
  'vw.tryOther': ('Try a different slot', 'جرّب موعداً آخر'),
  'vw.browseSimilar': ('Browse similar properties', 'تصفّح عقارات مشابهة'),
  // reschedule (45)
  'vw.resched.title': (
    'The host suggested a new time',
    'اقترح المضيف وقتاً جديداً',
  ),
  'vw.resched.sub': (
    'The host cannot take your original time but offered others. Choose the one that suits you.',
    'لا يستطيع المضيف الالتزام بوقتك الأصلي لكنه اقترح أوقاتاً أخرى. اختر ما يناسبك.',
  ),
  'vw.original': ('Original request', 'الطلب الأصلي'),
  'vw.suggested': ('Times offered by the host', 'الأوقات التي اقترحها المضيف'),
  'vw.confirmNew': ('Confirm new time', 'تأكيد الوقت الجديد'),
  'vw.declineNew': ('Decline', 'رفض'),
  'vw.resched.error': (
    'We could not update your viewing. Please try again.',
    'تعذّر تحديث معاينتك. حاول مرة أخرى.',
  ),
  // cancel (46)
  'vw.cancel.title': ('Cancel viewing?', 'إلغاء المعاينة؟'),
  'vw.cancel.sub': (
    'Are you sure you want to cancel this viewing? This cannot be undone.',
    'هل أنت متأكد من إلغاء هذه المعاينة؟ لا يمكن التراجع عن ذلك.',
  ),
  'vw.cancel.keep': ('Keep viewing', 'الإبقاء على المعاينة'),
  'vw.cancel.yes': ('Yes, cancel viewing', 'نعم، إلغاء المعاينة'),
  'vw.cancel.error': (
    'We could not cancel this viewing. Nothing has changed. Please try again.',
    'تعذّر إلغاء هذه المعاينة. لم يتغيّر شيء. حاول مرة أخرى.',
  ),
  'vw.cancelled.title': ('Viewing cancelled', 'تم إلغاء المعاينة'),
  'vw.cancelled.sub': ('Your viewing has been cancelled.', 'تم إلغاء معاينتك.'),
  'vw.cancelled.byHost': (
    'The host cancelled this viewing.',
    'ألغى المضيف هذه المعاينة.',
  ),
  'vw.action.cancel': ('Cancel viewing', 'إلغاء المعاينة'),
  'vw.action.reschedule': ('Choose new time', 'اختيار وقت جديد'),
  'vw.viewed': ('Viewed', 'تمت المعاينة'),
  'vw.cancelled.next': (
    'You can schedule a new viewing at any time.',
    'يمكنك جدولة معاينة جديدة في أي وقت.',
  ),
  'vw.scheduleNew': ('Schedule new viewing', 'جدولة معاينة جديدة'),
  // detail (47)
  'vw.detail.title': ('Viewing details', 'تفاصيل المعاينة'),
  'vw.detail.about': ('Viewing', 'المعاينة'),
  'vw.slotType': ('Type', 'النوع'),
  'vw.onSite': ('On-site viewing', 'معاينة في الموقع'),
  'vw.mapPreview': ('Map preview', 'معاينة الخريطة'),
  // completed (48)
  'vw.completed.title': ('Viewing completed', 'اكتملت المعاينة'),
  'vw.completed.sub': (
    'Your viewing is complete. Thank you for using AQARATI.',
    'اكتملت معاينتك. شكراً لاستخدامك عقاراتي.',
  ),
  'vw.rate.title': (
    'How was your viewing experience?',
    'كيف كانت تجربة المعاينة؟',
  ),
  'vw.rate.sub': (
    'Your review is about {host}. Reviews are checked by our team before they are published.',
    'تقييمك عن {host}. يراجع فريقنا التقييمات قبل نشرها.',
  ),
  'vw.rate.write': ('Write a review', 'اكتب تقييماً'),
  'vw.rate.star': ('{n} of 5 stars', '{n} من 5 نجوم'),
  'vw.review.soon.title': ('Review your host', 'قيّم المضيف'),
  'vw.review.soon.body': (
    'Writing a review opens in the next update. Your completed viewing stays eligible.',
    'ستتوفر كتابة التقييم في التحديث القادم. تبقى معاينتك المكتملة مؤهلة للتقييم.',
  ),
  'vw.review.rules': (
    'A review has 1 to 5 stars and a comment of 10 to 500 characters. Every review is moderated before it is published.',
    'يتكوّن التقييم من 1 إلى 5 نجوم وتعليق من 10 إلى 500 حرف. يخضع كل تقييم للمراجعة قبل النشر.',
  ),
  'vw.review.close': ('Close', 'إغلاق'),
  // conflict (49)
  'vw.conflict.title': (
    'This time slot is no longer available',
    'هذا الموعد لم يعد متاحاً',
  ),
  'vw.conflict.sub': (
    'Someone else has taken this slot. Choose another available time to continue.',
    'حجز شخص آخر هذا الموعد. اختر وقتاً آخر متاحاً للمتابعة.',
  ),
  'vw.conflict.what': ('What happened', 'ما الذي حدث'),
  'vw.conflict.body': (
    'The time you chose was booked before your request was sent. Nothing was sent to the host.',
    'حُجز الوقت الذي اخترته قبل إرسال طلبك. لم يُرسل شيء إلى المضيف.',
  ),
  'vw.conflict.prev': ('Your previous choice', 'اختيارك السابق'),
  'vw.conflict.alt': (
    'Choose another available slot',
    'اختر موعداً آخر متاحاً',
  ),
  'vw.conflict.none': (
    'No other times are open right now. Try another day.',
    'لا توجد أوقات أخرى متاحة الآن. جرّب يوماً آخر.',
  ),
  'vw.selectNew': ('Select new slot', 'اختيار موعد جديد'),
  // my viewings (50, 51)
  'vw.my.title': ('My Viewings', 'معايناتي'),
  'vw.my.sub': (
    'Manage your viewing requests and appointments.',
    'أدر طلبات المعاينة والمواعيد.',
  ),
  'vw.f.all': ('All', 'الكل'),
  'vw.f.upcoming': ('Upcoming', 'القادمة'),
  'vw.f.past': ('Past', 'السابقة'),
  'vw.f.cancelled': ('Cancelled', 'الملغاة'),
  'vw.g.today': ('Today', 'اليوم'),
  'vw.g.tomorrow': ('Tomorrow', 'غداً'),
  'vw.g.thisWeek': ('This week', 'هذا الأسبوع'),
  'vw.g.later': ('Later', 'لاحقاً'),
  'vw.g.earlier': ('Earlier', 'سابقاً'),
  'vw.my.error': ('We could not load your viewings.', 'تعذّر تحميل معايناتك.'),
  'vw.my.row': (
    '{title}, {place}, {when}, {status}',
    '{title}، {place}، {when}، {status}',
  ),
  'vw.empty.title': ('No viewings yet', 'لا توجد معاينات بعد'),
  'vw.empty.sub': (
    'You have not requested any property viewings yet. Find a property you like and book a time to see it in person.',
    'لم تطلب أي معاينة عقار بعد. اعثر على عقار يعجبك واحجز موعداً لرؤيته.',
  ),
  'vw.empty.upcoming': (
    'No upcoming viewings. Requests and confirmed visits appear here.',
    'لا توجد معاينات قادمة. تظهر هنا الطلبات والزيارات المؤكدة.',
  ),
  'vw.empty.past': (
    'No past viewings yet. Completed visits appear here.',
    'لا توجد معاينات سابقة بعد. تظهر هنا الزيارات المكتملة.',
  ),
  'vw.empty.cancelled': ('No cancelled viewings.', 'لا توجد معاينات ملغاة.'),
  'vw.browse': ('Browse properties', 'تصفّح العقارات'),
  // status
  'vw.status.requested': ('Requested', 'قيد الانتظار'),
  'vw.status.confirmed': ('Confirmed', 'مؤكدة'),
  'vw.status.reschedule': ('New time offered', 'اقتراح وقت جديد'),
  'vw.status.declined': ('Declined', 'مرفوضة'),
  'vw.status.cancelled': ('Cancelled', 'ملغاة'),
  'vw.status.completed': ('Completed', 'مكتملة'),
  'vw.sum.requested': (
    'Waiting for the host to respond.',
    'بانتظار ردّ المضيف.',
  ),
  'vw.sum.confirmed': (
    'The host accepted. This appointment is on.',
    'قبل المضيف. الموعد قائم.',
  ),
  'vw.sum.reschedule': (
    'The host offered other times. Choose one to continue.',
    'اقترح المضيف أوقاتاً أخرى. اختر وقتاً للمتابعة.',
  ),
  'vw.sum.declined': (
    'The host could not take this request.',
    'لم يستطع المضيف قبول هذا الطلب.',
  ),
  'vw.sum.cancelled': ('This viewing was cancelled.', 'أُلغيت هذه المعاينة.'),
  'vw.sum.completed': (
    'The host marked this viewing as completed.',
    'أكّد المضيف اكتمال هذه المعاينة.',
  ),
  // accessibility
  'vw.a11y.date': ('{date}, {state}', '{date}، {state}'),
  'vw.a11y.slot': ('{time}, {state}', '{time}، {state}'),
  'vw.a11y.selected': ('selected', 'محدد'),
  'vw.a11y.photo': ('Photo of {title}', 'صورة {title}'),
  // demo controls (review builds only)
  'vw.demo.title': ('DEMO: simulate the host', 'تجريبي: محاكاة المضيف'),
  'vw.demo.confirm': ('Host confirms', 'المضيف يؤكد'),
  'vw.demo.decline': ('Host declines', 'المضيف يرفض'),
  'vw.demo.suggest': ('Host suggests times', 'المضيف يقترح أوقاتاً'),
  'vw.demo.complete': ('Mark completed', 'تحديد كمكتملة'),
  'vw.demo.conflict': (
    'Next send finds the slot taken',
    'الإرسال التالي يجد الموعد محجوزاً',
  ),
  'vw.demo.armed': (
    'Armed: the next send will hit the conflict state',
    'مُفعّل: سيصل الإرسال التالي إلى حالة التعارض',
  ),
};
