## ClaudyGod Infrastructure — Managed Services Guide

This guide covers the production setup using **managed services** for database and email:

- **Supabase PostgreSQL** (managed database)
- **Brevo SMTP** (managed email relay)
- **Grafana** (optional monitoring)
- **Shared Proxy** (Traefik v3.6)

---

## 🗄️ SUPABASE PostgreSQL Setup

### 1. Create Supabase Project

1. Go to https://supabase.com/
2. Click "Start your project"
3. Sign in with GitHub or email
4. Create a new project:
   - **Project name**: claudygod
   - **Password**: Generate strong password (will need later)
   - **Region**: Choose closest to your users
   - Click "Create new project"

### 2. Get Connection String

After project is created:

1. Go to **Project Settings** (gear icon)
2. Click **Database** tab
3. Look for **Connection string** section
4. Select **"Shared Pooler"** tab (IPv4, port 5432)
   - **NOT** "Direct Connection" (unless you need IPv6)
5. Copy the connection string:
   ```
   postgresql://postgres.ktzhbaqumdvypegnsgok:PASSWORD@aws-1-eu-central-1.pooler.supabase.com:5432/postgres
   ```
6. Replace `PASSWORD` with your actual password from step 1

### 3. Test Connection

```bash
# From your server, test the connection
psql "postgresql://postgres.ktzhbaqumdvypegnsgok:YOUR-PASSWORD@aws-1-eu-central-1.pooler.supabase.com:5432/postgres"

# Once connected, verify:
\l              # List databases
\du             # List users
\q              # Exit
```

### 4. Add to .env

```env
SUPABASE_CONNECTION_STRING=postgresql://postgres.ktzhbaqumdvypegnsgok:YOUR-PASSWORD@aws-1-eu-central-1.pooler.supabase.com:5432/postgres
```

### Supabase Features (Automatic)

✅ **Automatic Backups**: Supabase handles daily backups  
✅ **Replication**: Your data is replicated for high availability  
✅ **Scaling**: Automatically scales as your data grows  
✅ **Security**: Encrypted connections, regular security updates  
✅ **Monitoring**: Supabase dashboard shows database health  
✅ **Disaster Recovery**: Easy restore from backups  

---

## 📧 BREVO SMTP Setup

### 1. Create Brevo Account

1. Go to https://www.brevo.com/
2. Click "Sign Up"
3. Create account (use your corporate email)
4. Verify email address
5. Complete profile setup

### 2. Verify Sender Email

Brevo requires sender email verification for deliverability:

1. Go to **Senders & List** → **Senders**
2. Click **"Add a sender"**
3. Add sender email: `noreply@claudygod.org`
4. Complete verification (you'll receive email confirmation)
5. Click link in confirmation email to verify

### 3. Get SMTP Credentials

1. Go to **Settings** → **SMTP & API** → **SMTP Details**
2. You'll see:
   ```
   SMTP Server: smtp-relay.brevo.com
   Port: 587
   Login: a18467001@smtp-brevo.com
   ```
3. Click **"Show SMTP Key"** to reveal your SMTP password
4. Copy the SMTP key (long string like `RiPJ7W...`)

### 4. Add to .env

```env
EMAIL_SMTP_HOST=smtp-relay.brevo.com
EMAIL_SMTP_PORT=587
EMAIL_SMTP_USERNAME=a18467001@smtp-brevo.com
EMAIL_SMTP_PASSWORD=YOUR-BREVO-SMTP-KEY
EMAIL_FROM_NAME=ClaudyGod Music Ministries
EMAIL_FROM_ADDRESS=noreply@claudygod.org
EMAIL_ADMIN=admin@claudygod.org
```

### 5. Test SMTP Connection

```bash
# From your server, test SMTP connection
telnet smtp-relay.brevo.com 587

# You should see: 220 Welcome
# Type "quit" to exit
```

### Brevo Features (Automatic)

✅ **Deliverability**: Uses Brevo's reputation for email delivery  
✅ **Rate Limiting**: Automatic throttling to avoid spam filters  
✅ **Bounce Handling**: Tracks bounces and failures  
✅ **Spam Checking**: Checks emails before sending  
✅ **Analytics**: Track open rates, click rates, bounces  
✅ **DKIM/SPF**: Brevo handles authentication  

---

## 📊 GRAFANA MONITORING (Optional)

### 1. Access Grafana Dashboard

After deployment:

```bash
# Grafana will be available at:
https://metrics.claudygod.org

# Default credentials:
Username: admin
Password: (from GRAFANA_ADMIN_PASSWORD in .env)
```

### 2. First Time Setup

1. Login with admin credentials
2. You'll see "Welcome to Grafana"
3. Grafana is pre-configured with:
   - Prometheus data source (metrics from Traefik)
   - ClaudyGod dashboard (pre-built)
   - Alert rules (optional)

### 3. View Dashboards

1. Click **Dashboards** in left sidebar
2. Look for:
   - **Traefik** - reverse proxy metrics
   - **ClaudyGod API** - backend performance
   - **ClaudyGod Frontend** - frontend health

### 4. Change Admin Password

1. Click **Settings** (gear icon) in top right
2. Go to **Users**
3. Click **admin** user
4. Change password

### Optional: Disable Grafana

If you don't need Grafana, don't expose it:

In `.env`, leave empty:
```env
GRAFANA_DOMAIN=
```

Grafana will still run for internal metrics, but won't be exposed to the internet.

---

## 🚀 DEPLOYMENT WITH MANAGED SERVICES

### Step 1: Get All Connection Strings

Before deploying, have these ready:

```bash
# Supabase
SUPABASE_CONNECTION_STRING=postgresql://postgres.ktzhbaqumdvypegnsgok:PASSWORD@aws-1-eu-central-1.pooler.supabase.com:5432/postgres

# Brevo
EMAIL_SMTP_HOST=smtp-relay.brevo.com
EMAIL_SMTP_PORT=587
EMAIL_SMTP_USERNAME=a18467001@smtp-brevo.com
EMAIL_SMTP_PASSWORD=YOUR-BREVO-SMTP-KEY

# Other secrets
JWT_KEY=<openssl rand -base64 48>
ENCRYPTION_KEY=<openssl rand -base64 32>
REDIS_PASSWORD=<openssl rand -base64 32>
```

### Step 2: Configure .env

```bash
cd ~/apps/claudygod
cp .env.example .env
nano .env
```

Fill in all values from Step 1.

### Step 3: Deploy

```bash
# This docker-compose now:
# - Does NOT create local PostgreSQL
# - Uses Supabase connection string instead
# - Configures Brevo SMTP
# - Sets up Grafana (optional)
# - Keeps Redis for cache/sessions
# - Uses shared Traefik proxy

make deploy
```

### Step 4: Verify Database Connection

```bash
# Check API logs for database connection
docker compose logs -f api | grep -i "database\|connected"

# Should see "Connected to database" or similar
# If you see errors, check:
# 1. SUPABASE_CONNECTION_STRING is correct
# 2. Supabase project is running
# 3. Network connectivity to Supabase
```

### Step 5: Verify Email Configuration

```bash
# Test by sending contact form from website
# Check Brevo dashboard for sent emails:
# Settings → SMTP & API → Email activity

# Or test manually:
curl -X POST https://api.claudygod.org/api/v1/contact \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "message": "Test message",
    "subject": "Test subject"
  }'

# Should receive email at admin@claudygod.org
```

---

## 🔍 MONITORING WITH MANAGED SERVICES

### Supabase Monitoring

1. **Dashboard**: https://app.supabase.com/projects
2. Click your ClaudyGod project
3. View metrics:
   - **Database** tab: CPU, memory, connections
   - **Auth** tab: User signups, logins
   - **Logs** tab: Database queries

### Brevo Monitoring

1. **Dashboard**: https://app.brevo.com/
2. **Analytics** → **Email activity**:
   - Sent: Count of emails sent
   - Opens: Email open rates
   - Clicks: Link click tracking
   - Bounces: Failed delivery
   - Unsubscribes: Unsubscribe requests

### Grafana Monitoring (Optional)

1. Go to: https://metrics.claudygod.org
2. View dashboards:
   - **Traefik**: HTTP requests, latency, errors
   - **ClaudyGod API**: Response times, error rates
   - **ClaudyGod Frontend**: Page loads, performance

### Prometheus Metrics

Prometheus (in shared proxy) scrapes metrics from:
- **Traefik**: HTTP requests, latencies, status codes
- **Redis**: Memory usage, commands, latency
- **API health**: Custom app metrics

---

## 🆘 TROUBLESHOOTING

### Database Connection Failed

**Error**: `connection refused` or `timeout`

**Check**:
1. Supabase project is running (check dashboard)
2. Connection string is correct (no typos)
3. IP whitelisting (Supabase → Project Settings → Database)
4. Network connectivity: `ping aws-1-eu-central-1.pooler.supabase.com`

**Fix**:
```bash
# Test connection directly
psql "postgresql://..."

# Verify migration ran
docker compose logs migrate | tail -20

# Restart API with working connection
docker compose restart api
```

### Email Not Sending

**Error**: Emails not arriving

**Check**:
1. Sender email is verified (Brevo → Senders & List)
2. SMTP credentials are correct
3. Brevo SMTP key is current (not expired)
4. Email not in spam folder

**Fix**:
```bash
# Check Brevo activity log
# https://app.brevo.com → Analytics → Email activity

# Check API logs for SMTP errors
docker compose logs api | grep -i "smtp\|email"

# Verify SMTP connection manually
telnet smtp-relay.brevo.com 587
```

### Grafana Not Loading

**Error**: Blank dashboard or no data

**Check**:
1. Prometheus is running (in shared proxy)
2. Traefik metrics are enabled
3. DNS resolves metrics.claudygod.org

**Fix**:
```bash
# Verify Grafana is healthy
docker compose ps grafana

# Check data source connection
# In Grafana: Settings → Data Sources → Prometheus

# Restart Grafana
docker compose restart grafana
```

---

## 📈 COST CONSIDERATIONS

### Supabase Pricing

**Free Plan**:
- 500MB database
- 100,000 realtime events
- Basic support

**Pro Plan**:
- Pay per use ($25/month + usage)
- Unlimited database size
- Priority support

For ClaudyGod, **Free Plan is probably sufficient** initially. Upgrade to Pro when needed.

### Brevo Pricing

**Free Plan**:
- 300 emails/day
- Unlimited contacts

**Pro Plan**:
- Pay as you go ($20/month)
- Unlimited emails
- Advanced features

For ClaudyGod, **Free Plan covers normal volume**. Upgrade if you send 300+ emails/day.

### Grafana Pricing

**Self-Hosted** (what we're using):
- Free (open source)
- You manage the server

---

## ✅ PRODUCTION CHECKLIST

- [ ] Supabase account created and project set up
- [ ] Supabase connection string tested and added to .env
- [ ] Brevo account created and SMTP verified
- [ ] Brevo sender email verified
- [ ] Brevo SMTP credentials added to .env
- [ ] All secrets filled in .env (JWT, ENCRYPTION, REDIS, etc.)
- [ ] DNS records updated (claudygod.org, api.claudygod.org)
- [ ] Shared proxy running (docker compose ps in ~/apps/proxy)
- [ ] Images pushed to GHCR
- [ ] docker compose up -d (in ~/apps/claudygod)
- [ ] Health checks pass (make health-check)
- [ ] Email test sent and received
- [ ] Grafana accessible (metrics.claudygod.org)
- [ ] Backups configured (optional, Supabase handles this)
- [ ] Monitoring set up (Grafana or Supabase dashboard)
- [ ] Team trained on monitoring dashboards

---

## 🎯 KEY BENEFITS OF MANAGED SERVICES

✅ **No Server Maintenance**: Supabase and Brevo handle updates  
✅ **Automatic Backups**: Supabase backs up your data automatically  
✅ **Better Reliability**: Enterprise-grade infrastructure  
✅ **Compliance**: GDPR, SOC2, ISO 27001 ready  
✅ **Support**: Dedicated support teams available  
✅ **Cost Effective**: Pay only for what you use  
✅ **Peace of Mind**: Focus on your application, not infrastructure  

---

## 📚 FURTHER READING

- **Supabase Docs**: https://supabase.com/docs
- **Brevo SMTP Guide**: https://help.brevo.com/hc/en-us/articles/209460026-How-to-use-SMTP
- **Grafana Docs**: https://grafana.com/docs
- **Traefik Docs**: https://doc.traefik.io/

---

**Last Updated**: 2026-05-25  
**Setup Version**: 2.0 (Managed Services)  
**Database**: Supabase PostgreSQL  
**Email**: Brevo SMTP Relay  
**Monitoring**: Grafana + Prometheus
