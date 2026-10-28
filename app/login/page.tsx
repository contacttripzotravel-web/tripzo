import { signIn } from "@/lib/actions/auth";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  const params = await searchParams;

  return (
    <main className="mx-auto flex min-h-screen max-w-sm flex-col justify-center gap-4 px-4">
      <h1 className="text-2xl font-bold">Log in to Tripzo</h1>

      {params.message && (
        <p className="text-sm text-green-600">
          {params.message}
        </p>
      )}

      {params.error && (
        <p className="text-sm text-red-600">
          {params.error}
        </p>
      )}

      <form action={signIn} className="flex flex-col gap-3">
        <input
          name="email"
          type="email"
          placeholder="Email"
          required
          className="rounded border px-3 py-2"
        />

        <input
          name="password"
          type="password"
          placeholder="Password"
          required
          className="rounded border px-3 py-2"
        />

        <button
          type="submit"
          className="rounded bg-black px-3 py-2 text-white"
        >
          Log in
        </button>
      </form>

      <a href="/signup" className="text-sm underline">
        Need an account? Sign up
      </a>
    </main>
  );
}
