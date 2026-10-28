
import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export default async function TripsPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { data: trips, error } = await supabase
    .from("itineraries")
    .select(
      "id, reference_code, pickup_location, drop_location, start_date, end_date, status"
    )
    .eq("guest_id", user.id)
    .order("created_at", { ascending: false });

  if (error) {
    return (
      <main className="mx-auto flex min-h-screen max-w-2xl flex-col gap-4 px-4 py-12">
        <h1 className="text-2xl font-bold">My trips</h1>
        <p className="text-red-600">
          Unable to load your trips. Please try again later.
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col gap-4 px-4 py-12">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">My trips</h1>

        <Link
          href="/trips/new"
          className="rounded bg-black px-3 py-2 text-sm text-white"
        >
          Post a trip
        </Link>
      </div>

      {!trips?.length && (
        <p className="text-neutral-600">
          No trips yet. Post your first trip to receive driver quotations.
        </p>
      )}

      <div className="flex flex-col gap-3">
        {trips?.map((trip) => (
          <Link
            key={trip.id}
            href={`/trips/${trip.id}`}
            className="rounded border p-4 hover:bg-neutral-50"
          >
            <p className="font-medium">
              {trip.pickup_location} → {trip.drop_location}
            </p>

            <p className="text-sm text-neutral-500">
              {trip.start_date} to {trip.end_date} · {trip.status} ·{" "}
              {trip.reference_code}
            </p>
          </Link>
        ))}
      </div>
    </main>
  );
}
