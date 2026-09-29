import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import './globals.css';
import { AuthProvider, ConfigGate } from '@/components/core';
export const metadata: Metadata = { title: 'Ученик — Sons of God', description: 'Школа ученичества Sons of God. Следовать за Иисусом и помогать другим следовать за Ним.', openGraph: { title: 'НЕ ПРИХОЖАНИН. УЧЕНИК.', description: 'Школа ученичества Sons of God', type: 'website' } };
export default function RootLayout({ children }: Readonly<{children: ReactNode}>) { return <html lang="ru"><body><AuthProvider><ConfigGate>{children}</ConfigGate></AuthProvider></body></html>; }