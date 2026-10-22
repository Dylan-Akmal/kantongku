import { defineStore } from 'pinia'
import http, { TOKEN_KEY, USER_KEY } from '@/api/http'

function readUser() {
  try {
    return JSON.parse(localStorage.getItem(USER_KEY) ?? 'null')
  } catch {
    return null
  }
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    token: localStorage.getItem(TOKEN_KEY),
    user: readUser(),
  }),

  getters: {
    isLoggedIn: (state) => Boolean(state.token),
  },

  actions: {
    persist(token, user) {
      this.token = token
      this.user = user
      localStorage.setItem(TOKEN_KEY, token)
      localStorage.setItem(USER_KEY, JSON.stringify(user))
    },

    clear() {
      this.token = null
      this.user = null
      localStorage.removeItem(TOKEN_KEY)
      localStorage.removeItem(USER_KEY)
    },

    async login(payload) {
      const { data } = await http.post('/auth/login', payload)
      this.persist(data.data.token, data.data.user)
    },

    async register(payload) {
      const { data } = await http.post('/auth/register', payload)
      this.persist(data.data.token, data.data.user)
    },

    async fetchMe() {
      const { data } = await http.get('/me')
      this.user = data.data
      localStorage.setItem(USER_KEY, JSON.stringify(data.data))
    },

    async logout() {
      try {
        await http.post('/auth/logout')
      } catch {
        // Token mungkin sudah tidak berlaku; tetap bersihkan sesi lokal.
      }
      this.clear()
    },
  },
})