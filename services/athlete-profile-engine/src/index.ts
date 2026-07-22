import { createAthleteProfileServer } from "./server.js";

const port = Number(process.env.PORT ?? 8788);
createAthleteProfileServer().listen(port, () => {
  process.stdout.write(`Athlete profile engine listening on ${port}\n`);
});
