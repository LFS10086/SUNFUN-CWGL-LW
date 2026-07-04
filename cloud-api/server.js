import crypto from 'node:crypto'
import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import cors from 'cors'
import express from 'express'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const PORT = Number(process.env.PORT || 8787)
const DATA_DIR = process.env.SANFENG_CLOUD_DATA_DIR || path.join(__dirname, 'data')
const JWT_SECRET = process.env.SANFENG_JWT_SECRET || 'change-this-secret-before-deploy'
const ALLOWED_ORIGINS = String(process.env.SANFENG_ALLOWED_ORIGINS || '')
  .split(',')
  .map((item) => item.trim())
  .filter(Boolean)
const app = express()

if (JWT_SECRET === 'change-this-secret-before-deploy') {
  console.warn('WARNING: SANFENG_JWT_SECRET is using the default value. Set a long random secret before production deployment.')
}

app.use(cors({
  credentials: false,
  origin(origin, callback) {
    if (!origin || ALLOWED_ORIGINS.length === 0 || ALLOWED_ORIGINS.includes(origin)) {
      callback(null, true)
      return
    }
    callback(new Error('Origin is not allowed by SANFENG_ALLOWED_ORIGINS'))
  },
}))
app.use(express.json({ limit: '80mb' }))

app.use((error, _req, res, next) => {
  if (error?.message === 'Origin is not allowed by SANFENG_ALLOWED_ORIGINS') {
    res.status(403).json({ message: '当前浏览器来源未被允许访问云端 API' })
    return
  }
  next(error)
})

const accountsFile = () => path.join(DATA_DIR, 'accounts.json')
const dealerFile = (dealerCode) => path.join(DATA_DIR, 'dealers', `${encodeURIComponent(dealerCode)}.json`)

async function ensureDataDir() {
  await fs.mkdir(path.join(DATA_DIR, 'dealers'), { recursive: true })
}

async function readJson(file, fallback) {
  try {
    return JSON.parse(await fs.readFile(file, 'utf8'))
  } catch (error) {
    if (error.code === 'ENOENT') return fallback
    throw error
  }
}

async function writeJson(file, value) {
  await fs.mkdir(path.dirname(file), { recursive: true })
  const tempFile = `${file}.${process.pid}.${Date.now()}.tmp`
  await fs.writeFile(tempFile, JSON.stringify(value, null, 2), 'utf8')
  await fs.rename(tempFile, file)
}

function nowIso() {
  return new Date().toISOString()
}

function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const hash = crypto.pbkdf2Sync(String(password || ''), salt, 120000, 32, 'sha256').toString('hex')
  return `${salt}:${hash}`
}

function verifyPassword(password, encoded) {
  if (!encoded || !encoded.includes(':')) return false
  const [salt] = encoded.split(':')
  return crypto.timingSafeEqual(Buffer.from(hashPassword(password, salt)), Buffer.from(encoded))
}

function normalizePublicAccount(account) {
  const publicAccount = { ...account }
  delete publicAccount.passwordHash
  return publicAccount
}

function signToken(account) {
  const payload = {
    accountId: account.id,
    dealerCode: account.dealerCode,
    role: account.role,
    exp: Date.now() + 1000 * 60 * 60 * 24 * 14,
  }
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url')
  const sig = crypto.createHmac('sha256', JWT_SECRET).update(body).digest('base64url')
  return `${body}.${sig}`
}

function readToken(req) {
  const header = req.headers.authorization || ''
  const token = header.startsWith('Bearer ') ? header.slice(7) : ''
  if (!token.includes('.')) return null
  const [body, sig] = token.split('.')
  const expected = crypto.createHmac('sha256', JWT_SECRET).update(body).digest('base64url')
  if (sig !== expected) return null
  const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'))
  if (payload.exp < Date.now()) return null
  return payload
}

function requireAuth(req, res, next) {
  const token = readToken(req)
  if (!token) {
    res.status(401).json({ message: '登录已过期，请重新登录' })
    return
  }
  req.auth = token
  next()
}

function requireSameDealer(req, res, next) {
  const dealerCode = req.params.dealerCode || req.body?.dealerCode
  if (dealerCode && dealerCode !== req.auth.dealerCode) {
    res.status(403).json({ message: '无权访问其他经销商数据' })
    return
  }
  next()
}

function emptyDealerData() {
  return {
    paymentQr: null,
    paymentQrs: {},
    customers: [],
    incomes: [],
    expenses: [],
    partners: [],
    salespeople: [],
    commissionPayments: [],
    tickets: [],
  }
}

app.get('/api/health', (_req, res) => {
  res.json({ ok: true, service: 'sanfeng-finance-cloud-api', time: nowIso() })
})

app.get('/api/health/storage', async (_req, res) => {
  const probeFile = path.join(DATA_DIR, `.health-${process.pid}-${Date.now()}.tmp`)
  try {
    await ensureDataDir()
    await fs.writeFile(probeFile, nowIso(), 'utf8')
    await fs.rm(probeFile, { force: true })
    res.json({ ok: true, dataDir: DATA_DIR, writable: true, time: nowIso() })
  } catch (error) {
    res.status(500).json({
      ok: false,
      dataDir: DATA_DIR,
      writable: false,
      message: error.message,
      time: nowIso(),
    })
  }
})

app.post('/api/auth/register', async (req, res) => {
  const dealerCode = String(req.body?.dealerCode || '').trim()
  const displayName = String(req.body?.displayName || dealerCode).trim()
  const role = String(req.body?.role || '经销商').trim()
  const password = String(req.body?.password || '')
  if (!dealerCode || password.length < 6) {
    res.status(400).json({ message: '请填写经销商代码和至少 6 位密码' })
    return
  }
  if (!['经销商', '财务', '店员'].includes(role)) {
    res.status(400).json({ message: '职位不正确' })
    return
  }
  const accounts = await readJson(accountsFile(), [])
  const sameDealer = accounts.filter((item) => item.dealerCode === dealerCode)
  if (sameDealer.length > 0 && role === '经销商') {
    res.status(409).json({ message: '该经销商代码已经存在经销商账户，请登录后由经销商账号添加员工' })
    return
  }
  if (sameDealer.length > 0 && !sameDealer.some((item) => item.role === '经销商')) {
    res.status(409).json({ message: '该经销商代码缺少经销商主账号，请先注册经销商账号' })
    return
  }
  const account = {
    id: `account-${crypto.randomUUID()}`,
    username: dealerCode,
    dealerCode,
    displayName,
    role,
    passwordHash: hashPassword(password),
    createdAt: nowIso(),
    updatedAt: nowIso(),
  }
  accounts.unshift(account)
  await writeJson(accountsFile(), accounts)
  if (sameDealer.length === 0) await writeJson(dealerFile(dealerCode), emptyDealerData())
  const data = await readJson(dealerFile(dealerCode), emptyDealerData())
  res.json({
    token: signToken(account),
    account: normalizePublicAccount(account),
    accounts: accounts.filter((item) => item.dealerCode === dealerCode).map(normalizePublicAccount),
    data,
  })
})

app.post('/api/auth/login', async (req, res) => {
  const dealerCode = String(req.body?.dealerCode || req.body?.username || '').trim()
  const role = String(req.body?.role || '').trim()
  const password = String(req.body?.password || '')
  const accounts = await readJson(accountsFile(), [])
  const account = accounts.find((item) => item.dealerCode === dealerCode && item.role === role)
  if (!account || !verifyPassword(password, account.passwordHash)) {
    res.status(401).json({ message: '经销商代码、职位或密码不正确' })
    return
  }
  const data = await readJson(dealerFile(dealerCode), emptyDealerData())
  res.json({
    token: signToken(account),
    account: normalizePublicAccount(account),
    accounts: accounts.filter((item) => item.dealerCode === dealerCode).map(normalizePublicAccount),
    data,
  })
})

app.get('/api/dealers/:dealerCode/snapshot', requireAuth, requireSameDealer, async (req, res) => {
  const accounts = await readJson(accountsFile(), [])
  const data = await readJson(dealerFile(req.params.dealerCode), emptyDealerData())
  res.json({
    accounts: accounts.filter((item) => item.dealerCode === req.params.dealerCode).map(normalizePublicAccount),
    data,
  })
})

app.put('/api/dealers/:dealerCode/snapshot', requireAuth, requireSameDealer, async (req, res) => {
  const dealerCode = req.params.dealerCode
  const incomingAccounts = Array.isArray(req.body?.accounts) ? req.body.accounts : []
  const incomingData = req.body?.data || emptyDealerData()
  const accounts = await readJson(accountsFile(), [])
  const existingById = new Map(accounts.map((item) => [item.id, item]))
  const nextDealerAccounts = incomingAccounts
    .filter((item) => item.dealerCode === dealerCode)
    .map((item) => {
      const existing = existingById.get(item.id)
      return {
        ...existing,
        ...item,
        dealerCode,
        passwordHash: existing?.passwordHash || hashPassword('123456'),
        updatedAt: nowIso(),
      }
    })
  const nextAccounts = [
    ...nextDealerAccounts,
    ...accounts.filter((item) => item.dealerCode !== dealerCode),
  ]
  await writeJson(accountsFile(), nextAccounts)
  await writeJson(dealerFile(dealerCode), incomingData)
  res.json({ ok: true, savedAt: nowIso() })
})

app.delete('/api/accounts/:accountId', requireAuth, async (req, res) => {
  const accounts = await readJson(accountsFile(), [])
  const operator = accounts.find((item) => item.id === req.auth.accountId)
  const target = accounts.find((item) => item.id === req.params.accountId)
  if (!operator || !target || operator.dealerCode !== target.dealerCode) {
    res.status(404).json({ message: '账户不存在' })
    return
  }
  if (operator.role !== '经销商') {
    res.status(403).json({ message: '只有经销商账号可以删除账户' })
    return
  }
  const remaining = accounts.filter((item) => item.id !== target.id)
  await writeJson(accountsFile(), remaining)
  if (target.role === '经销商') {
    await fs.rm(dealerFile(target.dealerCode), { force: true })
  }
  res.json({ ok: true })
})

app.post('/api/accounts', requireAuth, async (req, res) => {
  const displayName = String(req.body?.displayName || '').trim()
  const role = String(req.body?.role || '店员').trim()
  const password = String(req.body?.password || '')
  if (!displayName || password.length < 6) {
    res.status(400).json({ message: '请填写账户名称和至少 6 位密码' })
    return
  }
  if (!['经销商', '财务', '店员'].includes(role)) {
    res.status(400).json({ message: '职位不正确' })
    return
  }
  const accounts = await readJson(accountsFile(), [])
  const operator = accounts.find((item) => item.id === req.auth.accountId)
  if (!operator || operator.role !== '经销商') {
    res.status(403).json({ message: '只有经销商账号可以新增同代码账户' })
    return
  }
  const account = {
    id: `account-${crypto.randomUUID()}`,
    username: req.auth.dealerCode,
    dealerCode: req.auth.dealerCode,
    displayName,
    role,
    passwordHash: hashPassword(password),
    createdAt: nowIso(),
    updatedAt: nowIso(),
  }
  accounts.unshift(account)
  await writeJson(accountsFile(), accounts)
  res.json({
    account: normalizePublicAccount(account),
    accounts: accounts.filter((item) => item.dealerCode === req.auth.dealerCode).map(normalizePublicAccount),
  })
})

app.patch('/api/accounts/:accountId/password', requireAuth, async (req, res) => {
  const oldPassword = String(req.body?.oldPassword || '')
  const newPassword = String(req.body?.newPassword || '')
  if (newPassword.length < 6) {
    res.status(400).json({ message: '新密码至少 6 位' })
    return
  }
  const accounts = await readJson(accountsFile(), [])
  const account = accounts.find((item) => item.id === req.params.accountId && item.id === req.auth.accountId)
  if (!account || !verifyPassword(oldPassword, account.passwordHash)) {
    res.status(400).json({ message: '原密码不正确' })
    return
  }
  const nextAccounts = accounts.map((item) =>
    item.id === account.id
      ? { ...item, passwordHash: hashPassword(newPassword), updatedAt: nowIso() }
      : item,
  )
  await writeJson(accountsFile(), nextAccounts)
  res.json({ ok: true })
})

await ensureDataDir()
app.listen(PORT, () => {
  console.log(`Sanfeng cloud API listening on ${PORT}`)
  console.log(`Data directory: ${DATA_DIR}`)
})
