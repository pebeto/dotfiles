import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

// pi's bash tool waits forever when the model gives no timeout, so a looping test run hangs
// the session. Default to 300 s, the same as omp.
const DEFAULT_TIMEOUT_SECONDS = 300;

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    if (isToolCallEventType("bash", event) && event.input.timeout === undefined) {
      event.input.timeout = DEFAULT_TIMEOUT_SECONDS;
    }
  });
}
