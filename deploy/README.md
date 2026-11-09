# МГСС Төгсөгчдийн холбоо — байршуулах заавар

## 1. Supabase тохируулах (нэг удаа)
1. https://supabase.com дээр үнэгүй бүртгүүлж **New project** үүсгэнэ.
2. **SQL Editor → New query** руу орж `supabase-schema.sql` файлын агуулгыг бүтнээр нь буулгаад **Run** дарна.
3. **Project Settings → API** хэсгээс **Project URL** ба **anon public** түлхүүрийг хуулна.
4. `supabase-config.json` файлд оруулна:
   ```json
   { "url": "https://xxxx.supabase.co", "anonKey": "eyJ..." }
   ```
5. **Authentication → URL Configuration** дээр **Site URL**-д сайтынхаа хаягийг (жнь. https://mgss-tugsugchdiin-holboo-2026.vercel.app) бичнэ.

### И-мэйл баталгаажуулалт
- **Authentication → Providers → Email** дээр **Confirm email** асаалттай бол бүртгүүлсний дараа и-мэйлд ирсэн холбоосыг дарж байж нэвтэрнэ. Түр унтрааж болно.
- **Authentication → URL Configuration → Redirect URLs** хэсэгт сайтын хаягаа (`https://…vercel.app/**`) нэмнэ. Үгүй бол нууц үг сэргээх холбоос ажиллахгүй.
- Supabase-ийн үнэгүй и-мэйл илгээгч цагт цөөн захидал илгээдэг. Олон хэрэглэгчтэй бол **Project Settings → Auth → SMTP** дээр өөрийн и-мэйл тохируулна.

## 2. Админ болох
1. Сайт дээр өөрийн и-мэйлээр **Сүлжээнд нэгдэх** хэсгээр бүртгүүлж, и-мэйлээ баталгаажуулна.
2. Supabase **SQL Editor** дээр:
   ```sql
   insert into admins (user_id) select id from auth.users where email = 'tanii@email.mn';
   ```
3. `/admin` хаягаар орж тэр и-мэйл, нууц үгээрээ нэвтэрнэ.

## 3. Байршуулах
Энэ хавтасны бүх файлыг GitHub repo-ийн үндсэн хэсэгт оруулахад Vercel автоматаар шинэчилнэ.

## Шинэчлэл 2 (ажлын зар, зураг, утасны нууцлал)
Өмнө нь схемээ ажиллуулсан бол `supabase-schema.sql`-ийн "ШИНЭЧЛЭЛ 2" хэсгийг SQL Editor-т ажиллуулна.

## Facebook-т хуваалцах зураг
`og.jpg`-г repo-ийн үндсэнд байршуулна. Домэйн тогтсоны дараа `index.html` доторх `content="/og.jpg"`-г `https://таны-домэйн/og.jpg` болгож солиорой.
