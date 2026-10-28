"use server";

import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import { itinerarySchema } from "@/lib/validation/itinerary";

export async function createItinerary(formData: FormData) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  let daysRaw: unknown = [];
  try {
    daysRaw = JSON.parse(String(formData.get("days") || "[]"));
  } catch {
    redirect("/trips/new?error=Could not read day-by-day stops");
  }

  const parsed = itinerarySchema.safeParse({
    pickupLocation: formData.get("pickupLocation"),
    dropLocation: formData.get("dropLocation"),
    startDate: formData.get("startDate"),
    endDate: formData.get("endDate"),
    passengerCount: formData.get("passengerCount"),
    vehiclePreference: formData.get("vehiclePreference") || undefined,
    luggageRequirements: formData.get("luggageRequirements") || undefined,
    specialRequirements: formData.get("specialRequirements") || undefined,
    additionalNotes: formData.get("additionalNotes") || undefined,
    days: daysRaw,
  });

  if (!parsed.success) {
    redirect(`/trips/new?error=${encodeURIComponent(parsed.error.issues[0]?.message ?? "Invalid input")}`);
  }

  const d = parsed.data;

  const { data: itinerary, error } = await supabase
    .from("itineraries")
    .insert({
      guest_id: user.id,
      pickup_location: d.pickupLocation,
      drop_location: d.dropLocation,
      start_date: d.startDate,
      end_date: d.endDate,
      passenger_count: d.passengerCount,
      vehicle_preference: d.vehiclePreference ?? null,
      luggage_requirements: d.luggageRequirements ?? null,
      special_requirements: d.specialRequirements ?? null,
      additional_notes: d.additionalNotes ?? null,
    })
    .select("id")
    .single();

  if (error || !itinerary) {
    redirect(`/trips/new?error=${encodeURIComponent(error?.message ?? "Could not create itinerary")}`);
  }

  for (let i = 0; i < d.days.length; i++) {
    const day = d.days[i];
    if (!day) continue;

    const { data: dayRow, error: dayError } = await supabase
      .from("itinerary_days")
      .insert({
        itinerary_id: itinerary.id,
        day_number: i + 1,
        day_date: day.dayDate,
      })
      .select("id")
      .single();

    if (dayError || !dayRow) {
      redirect(`/trips/new?error=${encodeURIComponent(dayError?.message ?? "Could not save day")}`);
    }

    const stopsPayload = day.stops.map((location, idx) => ({
      itinerary_day_id: dayRow.id,
      stop_order: idx + 1,
      location_name: location,
    }));

    const { error: stopsError } = await supabase.from("itinerary_stops").insert(stopsPayload);
    if (stopsError) {
      redirect(`/trips/new?error=${encodeURIComponent(stopsError.message)}`);
    }
  }

  redirect(`/trips/${itinerary.id}`);
}
