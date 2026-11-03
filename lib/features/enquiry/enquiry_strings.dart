/// Copy for the property enquiry, offer, gallery, compare and review pages. Merged into FlowStrings.
/// ARABIC IS DRAFT COPY and needs native review before launch.
const Map<String, (String, String)> enquiryStrings = {
  // enquiry
  'enq.title': ('Enquire about this property', 'استفسر عن هذا العقار'),
  'enq.sub': (
    'Send your details and a question to the listing owner.',
    'أرسل بياناتك وسؤالك إلى صاحب الإعلان.',
  ),
  'enq.name': ('Full name', 'الاسم الكامل'),
  'enq.name.err': ('Enter your full name.', 'أدخل اسمك الكامل.'),
  'enq.email': ('Email address (optional)', 'البريد الإلكتروني (اختياري)'),
  'enq.phone': ('Mobile number (optional)', 'رقم الجوال (اختياري)'),
  'enq.contact.err': (
    'Add an email address or a mobile number so the owner can reply.',
    'أضف بريداً إلكترونياً أو رقم جوال ليتمكن المالك من الرد.',
  ),
  'enq.contact.help': (
    'Add at least one way for the owner to reply.',
    'أضف وسيلة واحدة على الأقل ليرد عليك المالك.',
  ),
  'enq.msg': ('Message', 'الرسالة'),
  'enq.msg.hint': (
    'Ask about availability, the price or a viewing.',
    'اسأل عن التوفر أو السعر أو موعد معاينة.',
  ),
  'enq.msg.err': ('Write at least 10 characters.', 'اكتب 10 أحرف على الأقل.'),
  'enq.save': ('Save enquiry', 'حفظ الاستفسار'),
  'enq.note': (
    'Delivery to listing owners is not connected to the live service yet. Your enquiry is saved on this device.',
    'إرسال الاستفسارات إلى أصحاب الإعلانات غير متصل بالخدمة المباشرة بعد. يُحفظ استفسارك على هذا الجهاز.',
  ),
  'enq.done.title': ('Enquiry saved', 'تم حفظ الاستفسار'),
  'enq.done.sub': (
    'Your enquiry about {p} is saved on this device.',
    'تم حفظ استفسارك عن {p} على هذا الجهاز.',
  ),
  'enq.done.warn': (
    'It has not been delivered to the listing owner, because enquiry delivery is not connected to the live service yet.',
    'لم يصل إلى صاحب الإعلان لأن إرسال الاستفسارات غير متصل بالخدمة المباشرة بعد.',
  ),
  'enq.back': ('Back to listing', 'العودة إلى الإعلان'),

  // offer
  'off.title': ('Make an offer', 'قدّم عرضاً'),
  'off.sub': ('Listed at {price}', 'السعر المعلن {price}'),
  'off.field': ('Your offer (OMR)', 'عرضك (ر.ع.)'),
  'off.err': ('Enter an amount greater than zero.', 'أدخل مبلغاً أكبر من صفر.'),
  'off.ack': (
    'I understand an offer is not binding until the owner accepts it.',
    'أدرك أن العرض غير ملزم حتى يقبله المالك.',
  ),
  'off.ack.err': ('Confirm to continue.', 'أكّد للمتابعة.'),
  'off.save': ('Save offer', 'حفظ العرض'),
  'off.note': (
    'Delivery to listing owners is not connected to the live service yet. Your offer is saved on this device.',
    'إرسال العروض إلى أصحاب الإعلانات غير متصل بالخدمة المباشرة بعد. يُحفظ عرضك على هذا الجهاز.',
  ),
  'off.done.title': ('Offer saved', 'تم حفظ العرض'),
  'off.done.sub': (
    'Your offer of {amount} for {p} is saved on this device.',
    'تم حفظ عرضك البالغ {amount} على {p} على هذا الجهاز.',
  ),
  'off.done.warn': (
    'It has not been delivered to the listing owner, because offer delivery is not connected to the live service yet.',
    'لم يصل إلى صاحب الإعلان لأن إرسال العروض غير متصل بالخدمة المباشرة بعد.',
  ),

  // gallery
  'gal.photos': ('Photos', 'الصور'),
  'gal.video': ('Video', 'الفيديو'),
  'gal.count': ('{a} of {b}', '{a} من {b}'),
  'gal.none': (
    'This listing has no photos yet.',
    'لا توجد صور لهذا الإعلان بعد.',
  ),
  'gal.novideo': ('This listing has no video.', 'لا يوجد فيديو لهذا الإعلان.'),
  'gal.err': ('This photo could not be loaded.', 'تعذّر تحميل هذه الصورة.'),
  'gal.play': ('Play video', 'تشغيل الفيديو'),
  'gal.pause': ('Pause video', 'إيقاف الفيديو مؤقتاً'),
  'gal.videoN': ('Video {n}', 'الفيديو {n}'),

  // compare
  'cmp.title': ('Compare properties', 'مقارنة العقارات'),
  'cmp.sub': ('{n} selected', 'تم اختيار {n}'),
  'cmp.empty.t': ('Nothing to compare', 'لا شيء للمقارنة'),
  'cmp.empty.b': (
    'Select properties from Saved to compare them here.',
    'اختر عقارات من المحفوظات لمقارنتها هنا.',
  ),
  'cmp.err': (
    'We could not load the properties. Check your connection and try again.',
    'تعذّر تحميل العقارات. تحقق من الاتصال وحاول مرة أخرى.',
  ),
  'map.idle.t': ('Map', 'الخريطة'),
  'map.idle.b': ('Loads when you scroll here.', 'تُحمَّل عند الوصول إليها.'),
  'map.show': ('Show map', 'عرض الخريطة'),
  'map.loading': ('Loading map…', 'جارٍ تحميل الخريطة…'),
  'map.failed.t': ('The map could not load', 'تعذّر تحميل الخريطة'),
  'map.failed.b': ('Check your connection and try again. The listing details above are unaffected.', 'تحقق من الاتصال وحاول مرة أخرى. تفاصيل العقار لم تتأثر.'),
  'map.retry': ('Try again', 'حاول مرة أخرى'),
  'map.chip.live': ('Live map · Google Maps', 'خريطة مباشرة · Google Maps'),
  'map.chip.demo': ('Live map · sample listing locations', 'خريطة مباشرة · مواقع عقارات تجريبية'),
  'cmp.price': ('Price', 'السعر'),
  'cmp.swipe': ('Swipe sideways to see every property in the table.', 'مرّر جانباً لرؤية كل العقارات في الجدول.'),
  'cmp.type': ('Type', 'النوع'),
  'cmp.beds': ('Bedrooms', 'غرف النوم'),
  'cmp.baths': ('Bathrooms', 'دورات المياه'),
  'cmp.area': ('Area', 'المساحة'),
  'cmp.parking': ('Parking', 'مواقف السيارات'),
  'cmp.tx': ('Transaction', 'نوع الصفقة'),
  'cmp.amen': ('Amenities', 'المرافق'),
  'cmp.none': ('None listed', 'لا توجد مرافق مدرجة'),
  'cmp.open': ('View property', 'عرض العقار'),
  'cmp.verified': ('Verified listing', 'إعلان موثّق'),
  'cmp.na': ('Not listed', 'غير مذكور'),
  'cmp.tx.buy': ('For sale', 'للبيع'),
  'cmp.tx.rent': ('For rent', 'للإيجار'),
  'cmp.tx.lease': ('Lease', 'عقد إيجار طويل'),

  // review eligibility
  'rev.title': ('Reviews', 'التقييمات'),
  'rev.about': ('About {name}', 'حول {name}'),
  'rev.t': (
    'Reviews come from completed work',
    'التقييمات تأتي من الأعمال المنجزة',
  ),
  'rev.b': (
    'You can review {name} after the engagement is confirmed by both you and {name}. A call, a WhatsApp message or a visit on its own does not open a review.',
    'يمكنك تقييم {name} بعد أن تؤكد أنت و{name} إتمام التعاقد. لا يفتح الاتصال أو رسالة واتساب أو الزيارة وحدها باب التقييم.',
  ),
  'rev.b2': (
    'Published reviews appear on the profile once they are approved.',
    'تظهر التقييمات المنشورة في الملف بعد اعتمادها.',
  ),
};
