import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Tripzo",
  description: "Share your itinerary. Compare local driver quotations. Choose your trip.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
