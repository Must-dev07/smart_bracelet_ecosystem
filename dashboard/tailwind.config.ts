import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#eef7ff',
          100: '#d9ecff',
          200: '#bcdfff',
          300: '#8ecbff',
          400: '#59adff',
          500: '#338bfc',
          600: '#1d6cf1',
          700: '#1556de',
          800: '#1846b4',
          900: '#193e8d',
          950: '#142757',
        },
      },
    },
  },
  plugins: [],
};

export default config;
