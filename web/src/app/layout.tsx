import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";
import Link from "next/link";

const geistSans = localFont({
  src: "./fonts/GeistVF.woff",
  variable: "--font-geist-sans",
  weight: "100 900",
});
const geistMono = localFont({
  src: "./fonts/GeistMonoVF.woff",
  variable: "--font-geist-mono",
  weight: "100 900",
});

export const metadata: Metadata = {
  title: "Create Next App",
  description: "Generated by create next app",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased  bg-gray-100 `}
      >
        <div className="flex items-center justify-center w-full gap-2">
          <Link href="/login">Login</Link>/
          <Link href="/register">Register</Link>/<Link href="/chat">Chat</Link>/
          <Link href="/update_password">Update password</Link>
        </div>
        {children}
      </body>
    </html>
  );
}
