/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        'pdtf-orange': '#E97B2D',
        'pdtf-orange-dark': '#D66A1F',
        'pdtf-navy': '#1E3A5F',
        'pdtf-navy-light': '#2D4A6F',
        'pdtf-stone': '#F5F0EB',
        'pdtf-stone-light': '#FAF8F5',
        'pdtf-teal': '#0D9488',
        'pdtf-teal-light': '#CCFBF1',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
        heading: ['Space Grotesk', 'Inter', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
