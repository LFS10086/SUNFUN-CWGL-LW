const base = (process.env.SANFENG_CLOUD_API_URL || 'http://127.0.0.1:8787').replace(/\/+$/, '')
const roleDealer = '\u7ecf\u9500\u5546'
const displayName = '\u6d4b\u8bd5\u7ecf\u9500\u5546'
const customerName = '\u4e91\u7aef\u6d4b\u8bd5\u9879\u76ee'

async function request(path, { method = 'GET', token, body } = {}) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  const payload = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(`${method} ${path}: ${JSON.stringify(payload)}`)
  return payload
}

const dealerCode = `JLTEST${Date.now().toString().slice(-6)}`
const password = '123456'
await request('/api/health')
await request('/api/health/storage')
const reg = await request('/api/auth/register', {
  method: 'POST',
  body: { dealerCode, displayName, role: roleDealer, password },
})
const login = await request('/api/auth/login', {
  method: 'POST',
  body: { dealerCode, role: roleDealer, password },
})
await request(`/api/dealers/${dealerCode}/snapshot`, {
  method: 'PUT',
  token: reg.token,
  body: {
    accounts: login.accounts,
    data: {
      customers: [{ id: 'cus-test', projectNo: 'SF-TEST-001', name: customerName, budget: [] }],
      incomes: [],
      expenses: [],
      partners: [],
      salespeople: [],
      commissionPayments: [],
      tickets: [],
      paymentQrs: {},
    },
  },
})
const snapshot = await request(`/api/dealers/${dealerCode}/snapshot`, { token: reg.token })

console.log(JSON.stringify({
  ok: true,
  base,
  dealerCode,
  accountCount: snapshot.accounts.length,
  customer: snapshot.data.customers[0]?.name,
}, null, 2))
