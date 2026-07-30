import { redirect } from "next/navigation";

// TODO: replace with the real public welcome/marketing page (next phase).
export default function RootPage() {
  redirect("/admin");
}
