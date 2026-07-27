import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Smart Bracelet — Doctor Dashboard',
  description:
    'Clinician dashboard for the newborn smart bracelet monitoring ecosystem. Not a medical diagnosis device.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
