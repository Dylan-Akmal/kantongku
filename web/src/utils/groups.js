export const roleLabels = {
  owner: 'Pemilik',
  member: 'Anggota',
}

/** "Dylan Akmal" menjadi "DA". */
export function initials(name) {
  return (name ?? '?')
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0].toUpperCase())
    .join('')
}