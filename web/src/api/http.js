import axios from 'axios'

export const TOKEN_KEY = 'kantongku_token'
export const USER_KEY = 'kantongku_user'

const http = axios.create({
  baseURL: import.meta.env.VITE_API_URL ?? 'http://127.0.0.1:8000/api',
  headers: { Accept: 'application/json' },
})

http.interceptors.request.use((config) => {
  const token = localStorage.getItem(TOKEN_KEY)
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

http.interceptors.response.use(
  (response) => response,
  (error) => {
    const isAuthRequest = error.config?.url?.startsWith('/auth/')

    if (error.response?.status === 401 && !isAuthRequest) {
      localStorage.removeItem(TOKEN_KEY)
      localStorage.removeItem(USER_KEY)
      if (window.location.pathname !== '/login') {
        window.location.href = '/login'
      }
    }

    return Promise.reject(error)
  },
)

/** Pesan kesalahan dari server, atau teks cadangan bila server tidak menjawab. */
export function errorMessage(error, fallback = 'Terjadi kesalahan. Coba lagi.') {
  if (!error.response) {
    return 'Tidak bisa terhubung ke server. Pastikan API sedang berjalan.'
  }
  return error.response.data?.message ?? fallback
}

/** Kesalahan per kolom dari validasi server (422), mis. { email: ['...'] }. */
export function validationErrors(error) {
  return error.response?.data?.errors ?? {}
}

export default http