import { apiInitializer } from "discourse/lib/api";
import dIcon from "discourse-common/helpers/d-icon";

export default apiInitializer("1.34.0", (api) => {
  api.headerIcons.add(
    "autograder-rankings",
    <template>
      <li>
        <a
          id="autograder-rankings-link"
          class="icon"
          href="/autograder/rankings"
          title="랭킹"
          aria-label="랭킹"
        >
          {{dIcon "trophy"}}
        </a>
      </li>
    </template>,
    { before: "search" }
  );
});
