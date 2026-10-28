import Image from "next/image";
import Link from "next/link";

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col items-center justify-center gap-6 px-4 text-center">
      <Image src="/logo.png" alt="Tripzo" width={435} height={145} className="h-16 w-auto" priority />
      <p className="text-lg text-neutral-600">
        Share your itinerary. Compare local driver quotations. Choose your trip.
      </p>
      <div className="flex gap-4">
        <Link href="/signup" className="rounded bg-black px-4 py-2 text-white">
          Get started
        </Link>
        <Link href="/login" className="rounded border px-4 py-2">
          Log in
        </Link>
      </div>
    </main>
  );
}
