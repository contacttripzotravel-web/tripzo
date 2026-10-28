import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

type Stop = {
  id: string;
  stop_order: number;
  location_name: string;
};

type Day = {
  id: string;
  day_number: number;
  day_date: string;
  itinerary_stops: Stop[];
};

type Trip = {
  id: string;
  reference_code: string;
  pickup_location: string;
  drop_location: string;
  start_date: string;
  end_date: string;
  passenger_count: number;
  vehicle_preference: string | null;
  luggage_requirements: string | null;
  special_requirements: string | null;
  additional_notes: string | null;
  status: string;
  itinerary_days: Day[];
};

export default async function TripDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { data: trip } = await supabase
    .from("itineraries")
    .select("*, itinerary_days(*, itinerary_stops(*))")
    .eq("id", id)
    .single<Trip>();

  if (!trip) notFound();

  const days = [...(trip.itinerary_days ?? [])].sort(
    (a, b) => a.day_number - b.day_number
  );

  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col gap-4 px-4 py-12">
      <h1 className="text-2xl font-bold">
        {trip.pickup_location} → {trip.drop_location}
      </h1>

      <p className="text-neutral-600">
        {trip.reference_code} · {trip.status}
      </p>

      <p>
        {trip.start_date} to {trip.end_date} ·{" "}
        {trip.passenger_count} passengers
      </p>

      {trip.vehicle_preference && (
        <p>Vehicle: {trip.vehicle_preference}</p>
      )}

      {trip.luggage_requirements && (
        <p>Luggage: {trip.luggage_requirements}</p>
      )}

      {trip.special_requirements && (
        <p>Special requirements: {trip.special_requirements}</p>
      )}

      {trip.additional_notes && (
        <p>Notes: {trip.additional_notes}</p>
      )}

      <div className="flex flex-col gap-3">
        {days.map((day) => (
          <div key={day.id} className="rounded border p-3">
            <p className="font-medium">
              Day {day.day_number} — {day.day_date}
            </p>

            <ul className="list-disc pl-5">
              {[...(day.itinerary_stops ?? [])]
                .sort((a, b) => a.stop_order - b.stop_order)
                .map((stop) => (
                  <li key={stop.id}>
                    {stop.location_name}
                  </li>
                ))}
            </ul>
          </div>
        ))}
      </div>
    </main>
  );
}
