
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import TripForm from "./trip-form";

export default async function NewTripPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const params = await searchParams;

  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col gap-6 px-4 py-12">
      <h1 className="text-2xl font-bold">Post your trip</h1>
      <TripForm error={params.error} />
    </main>
  );
}
