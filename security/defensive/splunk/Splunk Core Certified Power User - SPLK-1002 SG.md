# Splunk Core Certified Power User - SPLK-1002 SG edition

## 1. Working with Time

### Must-know concepts

- `_time` is the event timestamp.
- `_time` is stored as epoch/UNIX time and displayed in a readable format in Splunk Web.
- Time filtering is efficient because events are indexed and searched by time.
- Common metadata fields include `host`, `source`, `sourcetype`, `index`, `_raw`, and `_time`.
- Always check the search time range, either through the Time Range Picker or through `earliest` and `latest` in the base search.
- If `earliest` and `latest` are specified in SPL, they override the Time Range Picker.
- If you specify only `earliest`, `latest` is implicitly `now()`.
- `date_*` fields, for example `date_hour`, are extracted from the raw event timestamp and may not reflect the user's timezone.

### Time modifiers

Typical syntax:

```spl
index=main sourcetype=... earliest=-24h latest=now
index=main sourcetype=... earliest=-7d@d latest=@d
```

| Syntax | Meaning |
|---|---|
| `-30m` | last 30 minutes |
| `-24h` | last 24 hours |
| `-7d@d` | seven days ago, snapped to the beginning of the day |
| `@d` | beginning of the current day |
| `@w0` or `@w7` | beginning of the week, Sunday |
| `@w1` | Monday |
| `@mon` | beginning of the month |
| `@q` | beginning of the quarter |

**Exam rule:** `@` performs snapping, meaning it rounds down to the boundary of the selected time unit.

Examples:

```spl
earliest=-h@h
```

Meaning: one hour ago, snapped to the beginning of that hour.

```spl
earliest=-mon@mon latest=@mon
```

Meaning: the complete previous month.

```spl
earliest=-7d@d latest=@d
```

Meaning: the last 7 complete days, excluding today.

### `bin`

`bin` groups numeric or time values into buckets.

```spl
... | bin _time span=2m
... | bin totalSales span=100
... | bin totalSales bins=10
```

Remember:

- `span` defines the bucket size.
- `bins` defines an approximate number of buckets.
- When used on `_time`, all events in the same bucket receive the same rounded time value.

### Time functions in `eval`

| Function | Meaning |
|---|---|
| `now()` | search start time |
| `time()` | time when `eval` processes the event |
| `relative_time(X,Y)` | calculates a relative time from X |
| `strftime(X,Y)` | epoch to formatted string |
| `strptime(X,Y)` | formatted string to epoch |

Examples:

```spl
... | eval yesterday=relative_time(now(),"-1d@d")
... | eval readable=strftime(_time,"%Y-%m-%d %H:%M:%S")
... | eval epoch=strptime(asctime,"%Y-%m-%d %H:%M:%S")
```

### `timechart`

`timechart` creates time-based aggregations. `_time` is always the X-axis.

```spl
... | timechart count
... | timechart span=1h count by usage
... | timechart span=1h sum(price) by product_name limit=5
```

Remember:

- `timechart` can have only one `by` field.
- If you do not specify `span`, Splunk chooses the bucket size automatically.
- `limit` controls how many series are shown when using `by`.
- Do not use `over _time` with `timechart`; `_time` is already implicit.

### `timewrap`

`timewrap` is used to compare time periods, for example week over week.

```spl
index=security "failed password" earliest=-14d@d latest=@d
| timechart span=1d count as Failures
| timewrap 1w
| rename _time as Day
| eval Day=strftime(Day,"%A")
```

Remember:

- It is used after `timechart`.
- Each period becomes a separate series.
- If the selected time range is not evenly divisible by the wrap period, one series may be partial.

### Timezone trap

Risky:

```spl
... date_hour>=2 date_hour<5
```

`date_hour` comes from the raw event and may not match the user's timezone. Better:

```spl
... | eval my_hour=strftime(_time,"%H")
| search my_hour>=2 AND my_hour<5
```

---

## 2. Statistical Processing

### Data series
Data series a sequence of related data points that are plotted in a visualization
Not all results can be visualized as a data series

| Type | Meaning | Example |
|---|---|---|
| Single-series | compares values for one category | count by `vendor_action` |
| Multi-series | compares values across multiple categories | count by `vendor_action` split by `user` |
| Time series | compares values over time | `timechart count by usage` |

Not every table produced by a search is suitable for visualization.

### Transforming commands

Transforming commands convert events into statistical tables.

Key commands:

- `chart`
- `timechart`
- `top`
- `rare`
- `stats`

### `chart`

Creates a visualizable table that is not necessarily time-based.

```spl
... | chart <stats-func>(<field>) over <row-split> by <column-split>
```

Examples:

```spl
index=sales sourcetype=vendor_sales
| chart count over VendorCountry
```

```spl
index=sales sourcetype=vendor_sales
| chart count over VendorCountry by product_name
```

Equivalent syntax:

```spl
... | chart count by VendorCountry product_name
```

Remember:

- `over` defines the X-axis / row split.
- `by` creates multiple series / column split.
- `chart` can use up to two split-by fields total.
- It supports wildcard field names inside statistical functions.
- Default `limit=10` for series created by `by`.
- Extra series are grouped into `OTHER`.
- `limit=0` removes the limit.
- `useother=f` hides `OTHER`.
- `usenull=f` hides null values.
- `span` in `chart` is for numeric buckets, not time buckets.

### `timechart` vs `chart`

| Feature | `chart` | `timechart` |
|---|---|---|
| Use case | generic visualizable table | time-based analysis |
| X-axis | defined with `over` | always `_time` |
| Split fields | up to 2 total | 1 `by` field only |
| Wildcarded fields in functions | yes | no |
| `span` | numeric buckets | time buckets |
| Default `limit` | 10 | 10 |

### `top`

Returns the most frequent values.

```spl
... | top field
... | top field1 field2
... | top field by groupfield limit=5 showperc=f countfield="Total Viewed"
```

Remember:

- Default top 10.
- Shows `percent` by default.
- `showperc=f` removes the percentage column.
- `countfield="Name"` renames the count column.
- `limit=0` shows all values.
- `top field1 field2` returns combinations of both fields.
- `top A by B` is not the same as `top B by A`.

### `rare`

Like `top`, but returns the least frequent values.

```spl
... | rare product_name limit=1 showperc=f
```

Remember:

- `top` = most common values.
- `rare` = least common values.
- Syntax and options are similar.

### `stats`

Calculates statistics on events/results.

```spl
... | stats <function>(field) as newname by field1 field2
```

Functions to know:

| Function | Meaning |
|---|---|
| `count` | total number of events |
| `count(field)` | events where the field has a value |
| `dc(field)` | distinct count |
| `sum(field)` | sum of numeric values |
| `min(field)` | minimum |
| `max(field)` | maximum |
| `avg(field)` | average |
| `median(field)` | median |
| `range(field)` | max minus min |
| `stdev(field)` | standard deviation |
| `var(field)` | variance |
| `values(field)` | unique values |
| `list(field)` | list of values, including duplicates |

Exam differences:

| Comparison | Difference |
|---|---|
| `count` vs `count(field)` | `count` counts all events; `count(field)` counts only events where the field exists and has a value |
| `dc(field)` vs `count(field)` | `dc` counts unique values; `count(field)` counts valued occurrences |
| `values(field)` vs `list(field)` | `values` removes duplicates; `list` keeps duplicates |
| `stats` vs `eventstats` | `stats` reduces results; `eventstats` adds a statistic to each row/event |
| `stats` vs `transaction` | `stats` is faster when a field-based summary is enough |

Examples:

```spl
index=security sourcetype=linux_secure failed
| stats count as FailedLogins
```

```spl
index=security sourcetype=linux_secure
| stats count(vendor_action) as ActionEvents, count as TotalEvents
```

```spl
index=network sourcetype=cisco_wsa_squid
| stats dc(s_hostname) as UniqueSites by cs_username
```

```spl
index=network sourcetype=cisco_wsa_squid
| stats values(s_hostname) as UniqueSites, list(s_hostname) as AllSites by cs_username
```

### `eval`

Creates or overwrites temporary fields in the search pipeline.

```spl
... | eval field=expression
... | eval field1=expression1, field2=expression2
```

Rules:

- Text values are case-sensitive.
- Strings use double quotes.
- Field names usually do not need quotes, but fields with spaces or special characters should use single quotes.
- Use `.` to concatenate strings and numbers.
- `eval` does not modify indexed data.

Useful functions:

| Function | Meaning |
|---|---|
| `round(X,Y)` | rounds X to Y decimal places |
| `pow(X,Y)` | X to the power of Y |
| `max(X,...)` | maximum argument |
| `min(X,...)` | minimum argument |
| `random()` | pseudo-random integer, no arguments |

Example:

```spl
index=network sourcetype=cisco_wsa_squid
| stats sum(sc_bytes) as Bytes by usage
| eval bandwidth=round(Bytes/pow(1024,2),2)
| sort - bandwidth
| rename bandwidth as "Bandwidth (MB)"
```

### `eval` inside `stats`

Very important pattern:

```spl
index=security sourcetype=linux_secure vendor_action=*
| stats count(eval(vendor_action="Accepted")) as Accepted,
        count(eval(vendor_action="Failed")) as Failed,
        count(eval(vendor_action="session opened")) as SessionOpened
```

Use it to count different conditions in the same `stats` command.

### `rename`

Renames fields in results.

```spl
... | rename productId AS ProductID, action AS "Customer Action"
```

Trap:

- After `rename`, use the new field name.
- If the new field name contains spaces, use double quotes.
- Wildcards are supported:

```spl
... | rename product* AS PROD*
```

### `sort`

Sorts results.

```spl
... | sort field
... | sort - field
... | sort + field
... | sort 10 - count
```

Remember:

- Default is ascending.
- `- field` = descending.
- `+ field` = ascending.
- Fields with spaces must be quoted.
- Strings are sorted lexicographically.
- Sort numeric values before converting them into formatted strings.

Spacing trap:

```spl
... | sort -Vendor, VendorCity
... | sort - Vendor, VendorCity
```

The space can change how the descending sort is interpreted.

---

## 3. Comparing Values

### Conditional and comparison functions

| Function | Use |
|---|---|
| `if(X,Y,Z)` | if X is true return Y, else Z |
| `case(X1,Y1,X2,Y2,...)` | returns the first value whose condition is true |
| `validate(X1,Y1,...)` | opposite of `case`: returns a message for the first false condition |
| `in(field,"a","b")` | true if field is one of the listed values |
| `searchmatch("string")` | true if the event matches the search string |
| `cidrmatch("CIDR",ip)` | true if the IP is in the subnet |
| `match(field,"regex")` | boolean regex match |
| `replace(X,Y,Z)` | replaces regex pattern Y with Z |
| `true()` | always true |
| `false()` | always false |
| `null()` | null value |
| `nullif(X,Y)` | null if X equals Y, else X |

### `case`

Likely exam topic.

```spl
... | eval Risk=case(score>=5,"High", score>=0,"Medium", true(),"Low")
```

Remember:

- Conditions are evaluated in order.
- Returns the first match.
- If no condition is true, returns null.
- Use `true(),"default"` as an else/default branch.

### Normalize before aggregating

Wrong or risky:

```spl
... | stats count by location
| eval location=case(location="BOS","Boston", true(),location)
```

This is too late because the groups were already created.

Correct:

```spl
... | eval location=case(location="BOS","Boston", location="LDN","London", true(),location)
| stats count by location
```

### `fieldformat`

Changes only how a value is displayed, not its underlying value.

```spl
... | fieldformat totalCount=tostring(totalCount,"commas")
```

Remember:

- Use it late in the pipeline.
- Useful for display formatting while keeping the value usable for math earlier.
- Difference from `eval`: `eval` changes the result value; `fieldformat` changes only the display.

### `where`

Filters results using eval-style expressions.

```spl
... | where removals > changes
... | where categoryId="STRATEGY"
... | where isnull(sum)
```

Remember:

- Case-sensitive for values.
- Strings use double quotes.
- Keeps only rows where the expression is true.
- Useful after transforming commands such as `stats` and `timechart`.

### Boolean precedence

Order:

1. Parentheses
2. `NOT`
3. `AND`
4. `OR`

### Wildcards in `where`

Do not use `*` as a wildcard in `where`.

Use:

```spl
... | where like(user,"adm%")
... | where user LIKE "adm%"
```

Rules:

- `%` = multiple characters.
- `_` = one single character.

### Null handling

```spl
... | where isnull(product_name)
... | where isnotnull(productId)
... | fillnull value="NULL" product_name
```

`fillnull` examples:

```spl
... | fillnull
... | fillnull value="NULL"
... | fillnull value=0 field1 field2
```

Remember:

- If `value` is not specified, default is `0`.
- You can limit the fields affected by `fillnull`.

---

## 4. Result Modification

### `untable` and `xyseries`

They are opposite commands.

| Command | Meaning |
|---|---|
| `untable` | converts a 2D/chart-like table into a flat/stats-like table |
| `xyseries` | converts a flat/stats-like table into a chartable table |

Syntax:

```spl
... | untable <x-field> <y-name-field> <y-data-field>
... | xyseries <x-field> <y-name-field> <y-data-field>
```

Example pattern:

```spl
... | stats sum(price) as sales by Vendor product_name
| where sales > 100
| xyseries Vendor product_name sales
| fillnull
```

Remember:

- `chart` is simpler when you just need a direct visualization.
- `stats ... | xyseries ...` is useful when you need to manipulate values before making the table chartable.

### `appendpipe`

Runs a subpipeline against the current result set and appends rows.

```spl
... | appendpipe [ stats sum(count) as count by usage ]
```

Remember:

- It does not replace original results.
- It adds rows at the end.
- Useful for subtotals and grand totals.
- You can use more than one `appendpipe`.

Example:

```spl
index=network sourcetype=cisco_wsa_squid usage!=Business
| stats count by usage, cs_username
| appendpipe [ stats sum(count) as count by usage | eval cs_username="Total for usage of ".usage ]
| sort usage
| appendpipe [ search cs_username="Total for*" | stats sum(count) as count | eval cs_username="GRAND TOTAL" ]
```

### `eventstats`

Calculates statistics and adds them to each row/event.

```spl
... | eventstats avg(lostSales) as averageLoss
| where lostSales > averageLoss
```

Key difference:

- `stats` aggregates and reduces results.
- `eventstats` keeps the results and adds a statistical field.

### `streamstats`

Calculates statistics progressively/streaming.

```spl
... | streamstats count as recentAttempts by bcg_ip
```

```spl
... | sort _time
| streamstats avg(price) as averageOrder window=100 current=false
```

Remember:

- It does not wait for the whole result set.
- Useful for running counts, rankings, moving averages.
- `window=N` limits the number of events considered.
- `current=false` excludes the current event.
- Default is `current=true`.

### Field modification functions

| Function | Use |
|---|---|
| `tostring(X,"commas")` | number with separators |
| `tostring(X,"duration")` | seconds to duration format |
| `tostring(X,"hex")` | number to hexadecimal |
| `tonumber(X,base)` | string to number |
| `lower(X)` | lowercase |
| `upper(X)` | uppercase |
| `substr(X,Y,Z)` | substring |
| `coalesce(X1,X2,...)` | first non-null value |

### `foreach`

Applies a template to multiple fields.

```spl
... | foreach www* [ eval <<FIELD>>=round(<<FIELD>>/(1024*1024),2) ]
```

Remember:

- Supports field wildcards.
- Uses `<<FIELD>>` as the placeholder.
- Useful for bulk conversions or repeated formatting.

### `coalesce`

Normalizes equivalent fields with different names.

```spl
(index=network sourcetype=cisco_wsa_squid) OR (index=web sourcetype=access_combined)
| eval oneIP=coalesce(clientip,c_ip)
```

Remember:

- Returns the first non-null value.
- Useful when different sourcetypes represent the same concept with different field names.

---

## 5. Correlation Analysis

### Correlation vs co-occurrence

| Concept | Meaning |
|---|---|
| Correlation | statistical relationship, usually numeric |
| Co-occurrence | frequency with which events/values appear together |

### `transaction`

Groups related events.

```spl
... | transaction JSESSIONID
... | transaction clientip maxspan=180s maxpause=1m
... | transaction JSESSIONID startswith=(action=addtocart) endswith=(action=purchase) keepevicted=1
```

Fields added by `transaction`:

| Field | Meaning |
|---|---|
| `duration` | seconds between first and last event in the transaction |
| `eventcount` | number of events in the transaction |
| `closed_txn` or `closedtxn` | complete or incomplete transaction |

Options:

| Option | Use |
|---|---|
| `maxspan` | maximum total duration of the transaction |
| `maxpause` | maximum pause between consecutive events |
| `maxevents` | maximum number of events in the transaction |
| `startswith` | start condition/event |
| `endswith` | end condition/event |
| `keepevicted=1` | keep incomplete transactions |

### Critical ordering rule

`transaction` expects events in reverse chronological order, meaning newest first.

If earlier commands changed event order, use:

```spl
... | sort - _time | transaction JSESSIONID
```

Trap: Splunk may not show an error when event order is wrong, but the results can be misleading.

### `closed_txn` and `keepevicted`

- `closed_txn=1`: conditions satisfied; complete transaction.
- `closed_txn=0`: conditions not satisfied; incomplete transaction.
- `keepevicted=1`: show incomplete transactions too.
- `keepevicted=0`: default; show only complete transactions when start/end conditions are used.

Example:

```spl
index=web sourcetype=access_combined
| transaction JSESSIONID startswith=(action=addtocart) endswith=(action=purchase) keepevicted=1
| search action=addtocart
| stats count(eval(closed_txn=0)) as Failed,
        count(eval(closed_txn=1)) as Completed,
        count as Attempted
| eval PercentCompleted=round((Completed*100)/Attempted,0)."%"
```

### When to use `transaction` vs `stats`

Use `transaction` when:

- You need to group events using multiple fields.
- You need start/end logic.
- You need time-based grouping using `maxspan` or `maxpause`.
- You need to keep raw event context.

Use `stats` when:

- A summary by field is enough.
- You want better performance.
- You need counting, summing, or aggregation.

Faster alternative pattern:

```spl
index=web sourcetype=access_combined
| stats values(action) as action values(product_name) as product_name by JSESSIONID
```

### Subsearch

A subsearch:

- Uses square brackets.
- Runs before the outer search.
- Must begin with a generating command, such as `search` or `inputlookup`.
- Passes results to the outer search as arguments.
- Can be multiple or nested.

Example:

```spl
index=network sourcetype=cisco_wsa_squid
[ search index=network sourcetype=cisco_wsa_squid
  | stats count by username
  | sort - count
  | return 1 username ]
| stats count by usage, username
```

### `append`

Appends results from a subsearch under the current results.

```spl
... | append [ search ... ]
```

Remember:

- Combines datasets even if the shapes differ.
- Does not automatically align rows with the same field value.
- Often followed by:

```spl
... | stats first(*) as * by productId
```

### `appendcols`

Adds columns by row position.

```spl
... | appendcols [ search ... ]
```

Trap:

- Safe only when row alignment is guaranteed.
- If one side has missing rows, results can be misleading.

### `join`

Joins results using common fields.

```spl
... | join product_name [ search ... ]
... | join type=left product_name [ search ... ]
```

Remember:

- Default is inner join.
- `type=left` keeps all outer results and adds matching inner results.
- Often slower than an `eval + stats` approach.

Alternative to `join`:

```spl
index=sales sourcetype=vendor_sales VendorID>=7000
| eval region=if(VendorID>=9000,"Africa","Asia")
| stats dc(region) as occurrences by product_name
| where occurrences=2
| fields product_name
```

### `union`

Combines datasets and returns a single result set.

```spl
| union datamodel:training.winauth_user_fails [ search index=security sourcetype=linux_secure FAIL* user=* ]
| eval user=coalesce(user, User)
| dedup user
| table user
| sort user
```

Can use:

- data model datasets
- saved searches
- lookups
- subsearches

---

## 6. Creating Knowledge Objects

### Search-time operation sequence

Memorize this order:

1. Extractions
2. Field aliases
3. Calculated fields
4. Lookups
5. Event types
6. Tags

Why it matters:

- A later object can use fields created earlier.
- An earlier object cannot use fields created later.
- A lookup can use a field alias because aliases run before lookups.
- A calculated field can use only extracted or aliased fields.

### Event types

An event type categorizes events using a basic search.

Remember:

- Must be a basic search.
- Cannot contain pipes.
- Cannot contain subsearches.
- Does not include a time range.
- Used to encode classification logic.
- Can be tagged.
- Search it with:

```spl
eventtype=<event_type_name>
```

Event type vs saved report:

| Event type | Saved report |
|---|---|
| categorizes events | saves a search/report |
| no time range | can include time range and formatting |
| runs at search time | intended for reuse/report/dashboard |
| basic search without pipes | can include pipeline and formatting |

### Workflow actions

Workflow actions allow actions from events/fields in results.

Types:

| Type | Meaning |
|---|---|
| GET | opens or retrieves data from an external resource |
| POST | sends field values to an external resource |
| Search | launches another search using field values |

They can appear in:

- event menu
- fields menu
- both

### Field aliases

A field alias gives an existing field a second name.

Remember:

- The original field remains available.
- Useful for normalization across sourcetypes.
- You may need one alias per sourcetype.
- Lookups can use field aliases because aliases run before lookups.

Conceptual example:

- `Username` and `User` can be normalized to `user`.

Trap: the overwrite option can replace or remove values, so understand it before enabling it.

### Tags

Tags label field=value pairs.

Remember:

- Tags are case-sensitive.
- One tag can be applied to multiple field/value pairs.
- One field/value pair can have multiple tags.
- Tags improve categorization and search readability.

Search examples:

```spl
tag=webserver
tag=w*
tag::host=webserver
```

### Search macros

A macro is a reusable SPL fragment.

Remember:

- Invoked with backticks:

```spl
`macro_name`
```

- Can have arguments:

```spl
`monthly_sales(euro,€,0.79)`
```

- Arguments are passed in the order they are defined.
- Macros can be nested.
- Macros can reference other knowledge objects.
- Macros can validate arguments.
- Preview expands the macro but does not allow editing in preview.
- If a macro definition starts with a command, do not include the leading pipe if it will be called after a pipe.

Trap:

If you define a macro as:

```spl
| stats count by user
```

and call it after a pipe, you may get a double pipe. Better:

```spl
stats count by user
```

### Calculated fields

A calculated field is saved `eval` logic as a knowledge object.

Remember:

- Reusable like a normal field.
- Avoids rewriting the same `eval` repeatedly.
- Can be based only on extracted or aliased fields.
- Runs after field aliases in the search-time sequence.

---

## 7. Creating Field Extractions

### When extraction happens

| Field type | When |
|---|---|
| Default fields | index time |
| Search fields | search time |
| Custom field extractions | index time or search time |

The Field Extractor, or FX:

- Creates persistent field extractions as knowledge objects.
- Can use regex or delimiters.
- Created extractions can be shared and reused.

### Regex extractions

Use regex when data is unstructured.

Remember:

- Regex is case-sensitive.
- `.` matches any character.
- `\` escapes special characters.
- Capture groups extract values.
- Typical named capture:

```regex
TraderID:(?<TraderID>\S+)
```

You may also see:

```regex
(?P<fieldname>...)
```

Examples:

```regex
user\s(\w+)
```

Captures alphanumeric word characters, but not `jean-luc` because `-` is not a word character.

```regex
user\s(\S+)
```

Captures any non-space sequence, including `jean-luc`.

### Regex best practices

- Keep regex simple and concise.
- Avoid excessive backtracking.
- Avoid too many `.*` patterns.
- Prefer `.*?` when non-greedy matching is needed.
- Use `+` instead of `*` when possible.
- Do not use regex if a delimiter is enough.

### FX warning

If you manually edit the regex generated by the Field Extractor, you cannot return to the normal assisted UI for that extraction.

### Delimited extractions

Use delimiters when events are structured consistently.

Examples:

- CSV
- comma-separated fields
- space-separated fields
- stable delimiter

Remember:

- Much simpler than regex when the structure is predictable.
- You can use delimiters for the structured part and regex for remaining fields.

---

## 8. Data Models

### Data model

A data model is a knowledge object that structures raw data to make it easier to use.

Remember:

- Pivot uses data models to create reports and dashboards without writing SPL directly.
- Data models can be accelerated.
- Data models are composed of datasets.
- all event database (root and children) contain: **constraints** and **fields** 

### Dataset types

A data model can contain:

| Dataset type | Meaning |
|---|---|
| Event dataset | based on event constraints |
| Search dataset | based on an arbitrary search |
| Transaction dataset | based on transaction logic |

### Hierarchy and inheritance

Remember:

- Data models are hierarchical.
- Child datasets inherit constraints from root and parent datasets.
- Child datasets also inherit fields from parent datasets.
- You can add additional constraints to narrow a child dataset.

Conceptual example:

- Root: all `access_combined` events.
- Child: only `status<400`.
- Child of child: only `action=purchase productId=*`.

### Adding fields

Fields can be added to a data model using:

- auto-extracted fields
- eval expression
- lookup
- regular expression
- Geo IP

### Field types

| Type | Meaning |
|---|---|
| String | alphanumeric |
| Number | numeric |
| Boolean | true/false or 1/0 |
| IPv4 | IP address |

Note: at least one IPv4 field is required to add Geo IP attributes.

### Field flags

| Flag | Meaning |
|---|---|
| Optional | field is not required |
| Required | Pivot returns only events where the field exists |
| Hidden | field is not shown to Pivot users |
| Hidden Required | required but hidden |

### Transaction dataset

Remember:

- Requires an existing event or search dataset.
- Required auto-extracted fields must already exist in the root event/search dataset.
- Transaction datasets do not benefit from persistent data model acceleration.

### Pivot

Pivot allows analysis without writing SPL directly.

You can:

- choose a dataset
- split rows
- split columns
- filter
- visualize
- save as report or dashboard panel
- drill down and view the generated search

Instant Pivot:

- Allows Pivot without a pre-existing data model.
- Starts from a non-transforming search.
- Creates a temporary/underlying data model.

### Data model acceleration

Two types:

| Type | Meaning |
|---|---|
| Ad hoc acceleration | created when a user uses Pivot; temporary |
| Persistent acceleration | explicitly enabled on the data model; persistent |

Ad hoc acceleration:

- Temporary.
- Valid only during the user's Pivot session.
- Saving a report/dashboard from the session does not make it accelerated later.
- Increases search head load.

Persistent acceleration:

- Requires admin permissions or the `accelerate_datamodel` capability.
- Not available for private data models.
- An accelerated data model cannot be modified.
- Uses persistent summaries.
- Used by Pivot, `datamodel`, and `tstats`.
- Supports multiple users.

What can be persistently accelerated:

- root event dataset
- root search dataset with only streaming commands
- eligible child datasets of eligible roots

What does not benefit:

- transaction datasets

### tsidx

Persistent acceleration summaries are optimized `tsidx` files.

Remember:

- They contain lexicon and posting lists.
- They help Splunk find terms/events efficiently.
- Summaries are updated regularly by Splunk.
- Old summary data is cleaned up by Splunk.

---

## 9. CIM Add-on - Common Information Model

The exam blueprint includes CIM, even if it was not deeply covered in the provided slide modules.

### What CIM is

CIM means Common Information Model.

It normalizes different data sources into common models so searches, dashboards, apps, and correlation searches can use consistent field names and logical datasets.

Practical example:

- A firewall may call the source IP `src_ip`.
- A proxy may call it `clientip`.
- Another log may call it `sourceAddress`.
- CIM normalization maps equivalent concepts to common fields such as `src`, `dest`, `user`, `action`, and similar fields.

### Why the exam asks about it

The exam may ask that:

- CIM is used for normalization.
- The CIM add-on contains knowledge objects.
- Data must be mapped to the correct data models.
- CIM helps correlation and apps such as Enterprise Security.
- CIM is not a separate database; it is a set of conventions and knowledge objects.

### CIM knowledge objects

Know these conceptually:

- data models
- event types
- tags
- field aliases
- calculated fields
- lookups or automatic lookups, where applicable

### How CIM is used for normalization

Conceptual process:

1. Identify the data type, for example Authentication, Network Traffic, Web, Malware, Change, or Email.
2. Check the required or recommended CIM fields.
3. Create the required field extractions, field aliases, calculated fields, lookups, or mappings.
4. Verify that events populate the correct data model.
5. Use Pivot, `tstats`, or dashboards based on that data model.

### CIM traps

- CIM does not ingest data by itself.
- CIM does not automatically fix unparsed logs.
- You still need to extract and normalize fields.
- CIM data models work well only if fields are correctly mapped.
- Do not confuse CIM with a visualization app. It is a normalization model/standard.

---

## 10. Command selection table

| Scenario in a question | Most likely command |
|---|---|
| aggregate events by field | `stats` |
| create a time-based chart | `timechart` |
| create a generic visualizable table | `chart` |
| show most common values | `top` |
| show least common values | `rare` |
| filter after `stats` or `timechart` using comparisons | `where` |
| filter events with simple terms | `search` |
| create a temporary field | `eval` |
| format the display only | `fieldformat` |
| replace null values | `fillnull` |
| add a global average to every row | `eventstats` |
| running count or running average | `streamstats` |
| add subtotal/grand total rows | `appendpipe` |
| 2D table to flat table | `untable` |
| flat table to chartable table | `xyseries` |
| group events with start/end logic | `transaction` |
| append rows from a subsearch | `append` |
| add columns by row position | `appendcols` |
| join on common field | `join` |
| combine named datasets/subsearches | `union` |
| normalize field names across sourcetypes | `coalesce`, field alias, CIM |
| extract fields from unstructured logs | FX regex |
| extract fields from CSV/structured logs | FX delimiter |

---

## 11. Frequent exam traps

### Time

- `earliest/latest` in SPL override the Time Range Picker.
- `@` always snaps down to a boundary.
- `date_hour` is not necessarily user-timezone aware.
- For timezone-aware hour extraction, use `strftime(_time,"%H")`.
- `timechart` has implicit `_time` and only one `by` field.

### Transforming commands

- `chart` can use two split fields total.
- `timechart` can use one split-by field only.
- `chart` supports wildcarded fields in functions; `timechart` does not.
- `top` shows percentage by default.
- `rare` uses similar options to `top`.
- `stats` does not automatically sort results.

### `stats`

- `count` is not the same as `count(field)`.
- `dc(field)` is not the same as `count(field)`.
- `values()` is not the same as `list()`.
- If you do not use `as`, generated field names can become long or inconvenient.

### `eval`, `where`, formatting

- Strings use double quotes.
- Values are case-sensitive.
- Concatenate with `.`, not `+`, especially for strings and numbers.
- `fieldformat` changes only the display.
- In `where`, do not use `*` as wildcard. Use `%` and `_` with `LIKE` or `like()`.
- Boolean order: parentheses, NOT, AND, OR.

### Result modification

- `appendpipe` adds rows, not columns.
- `eventstats` keeps events and adds a statistical field.
- `stats` reduces the result set.
- `streamstats` works in streaming mode.
- `xyseries` and `untable` are opposites.
- `coalesce` returns the first non-null value.

### Correlation

- `transaction` is resource-intensive.
- Before `transaction`, if order changed, use `sort - _time`.
- Use `transaction` for start/end, `maxspan`, `maxpause`, and raw context.
- If a summary is enough, use `stats`.
- `appendcols` can misalign rows if results are missing.
- `join` defaults to inner join.
- `eval + stats` is often better than `join`.

### Knowledge objects

- Sequence: Extractions -> Field aliases -> Calculated fields -> Lookups -> Event types -> Tags.
- Event type = basic search without pipes, subsearches, or time range.
- Report = saved search with time range and formatting.
- Tags are case-sensitive and apply to field/value pairs.
- Field alias does not remove the original field.
- A macro is invoked with backticks.
- A macro definition that starts with a command should not include the pipe if called after a pipe.
- A calculated field can use only extracted or aliased fields.

### Field extraction

- Regex is case-sensitive.
- Use regex for unstructured logs.
- Use delimiters for structured and consistent data.
- Named capture: `(?<field>...)`.
- If you manually edit the FX-generated regex, you cannot return to the assisted UI for that extraction.

### Data models

- Pivot uses datasets in a data model.
- Child datasets inherit constraints and fields.
- Transaction datasets do not benefit from persistent acceleration.
- Private data models cannot be accelerated persistently.
- An accelerated data model cannot be modified.
- Persistent acceleration uses `tsidx` summaries.
- Ad hoc acceleration is temporary and tied to the Pivot session.

### CIM

- CIM normalizes data; it does not ingest it by itself.
- You must map fields correctly.
- CIM data models work only when fields are populated and normalized.
