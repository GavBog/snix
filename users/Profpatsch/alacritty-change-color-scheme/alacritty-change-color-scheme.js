//@ts-check

// Step 3: Create the script
const dbus = require('dbus-native');
const fs = require('fs');
const assert = require('assert');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const {
  BasicTracerProvider,
  BatchSpanProcessor,
  ConsoleSpanExporter,
  SimpleSpanProcessor,
} = require('@opentelemetry/sdk-trace-base');
const opentelemetry = require('@opentelemetry/api');
const { hrTime } = require('@opentelemetry/core');
const { AsyncHooksContextManager } = require('@opentelemetry/context-async-hooks');
const { EventEmitter } = require('stream');
const { setTimeout } = require('node:timers/promises');
const { promisify } = require('util');

// NB: this code is like 80% copilot generated, and seriously missing error handling.
// It might break at any time, but for now it seems to work lol.

const programName = process.argv[1];
let themeDir = process.argv[2];
// read the dark alacritty theme file as first argument
let darkThemeName = process.argv[3] ?? 'alacritty_0_12';
// read the light alacritty theme file as second argument
let lightThemeName = process.argv[4] ?? 'dayfox';
assert(themeDir, 'Theme directory is required');

const darkTheme = getThemePathSync(darkThemeName);
const lightTheme = getThemePathSync(lightThemeName);

console.log(`Dark theme: ${darkTheme}`);
console.log(`Light theme: ${lightTheme}`);

class Bus {
  /**
   * @param {'session' | 'system'} type
   * @param {string} name
   */
  constructor(name, type) {
    this._name = name;
    this._type = type;
    switch (type) {
      case 'session':
        this._bus = dbus.sessionBus();
        break;
      case 'system':
        this._bus = dbus.systemBus();
        break;
    }
    this._bus.connection.once('error', err => {
      console.error(`${this._type} bus ${this._name} error: ${err}`);
      throw new Error(`${this._type} bus ${this._name} error: ${err}`);
    });
    this._bus.connection.once('end', () => {
      console.error(`${this._type} bus ${this._name} connection ended unexpectedly`);
      throw new Error(`${this._type} bus ${this._name} connection ended unexpectedly`);
    });
  }

  _busErrorMessages(what) {
    return `Error getting ${what} from ${this._type} bus ${this._name}`;
  }

  /**
   *
   * @param {string} name
   * @param {number} flags
   * @returns {Promise<number>}
   */
  requestName(name, flags) {
    return promisifyMethodAnnotate(
      this._bus,
      // @ts-ignore
      this._bus.requestName,
      this._busErrorMessages(`requesting name ${name}`),
      name,
      flags,
    );
  }

  /**
   * @param {{ [key: string]: unknown }} iface
   * @param {string} path
   * @param {{ name: string; methods: { [key: string]: unknown }; }} opts
   */
  exportInterface(iface, path, opts) {
    // @ts-ignore
    return this._bus.exportInterface(iface, path, opts);
  }

  /**
  /** Get object from bus, with the given interface (not checked!)
   * @template {{[key: string]: (...args: any[]) => Promise<unknown>}} Interface
   * @param {string} serviceName
   * @param {string} interfaceName
   * @param {string} objectName object name
   * @returns {Promise<Interface & EventEmitter >}
   */
  async getObject(serviceName, interfaceName, objectName) {
    //@ts-ignore
    const s = this._bus.getService(serviceName);

    /** @type {{[key: string]: Function}} */
    // @ts-ignore
    const iface = await promisifyMethodAnnotate(
      s,
      s.getInterface,
      this._busErrorMessages(`interface ${interfaceName}`),
      objectName,
      interfaceName,
    );

    if (!iface) {
      throw new Error(
        `Interface ${interfaceName} not found on object ${objectName} of service ${serviceName}`,
      );
    }

    // We need to promisify all methods on the interface
    const methodNames = Object.keys(iface.$methods ?? {});
    const methods = {};
    /** @type {Record<string, Function>} */
    for (const methodName of methodNames) {
      methods[methodName] = iface[methodName];
      iface[methodName] = (...args) =>
        promisifyMethodAnnotate(
          iface,
          methods[methodName],
          this._busErrorMessages(`method ${methodName}`),
          ...args,
        );
    }

    // @ts-ignore
    return iface;
  }
}

// Connect to the user session bus
const bus = new Bus('color-scheme', 'session');

opentelemetry.diag.setLogger({ ...console, verbose: console.log });

const exporter = new OTLPTraceExporter();
const consoleExporter = new ConsoleSpanExporter();
const provider = new BasicTracerProvider({
  //@ts-ignore
  resource: {
    attributes: {
      'service.name': 'alacritty-change-color-scheme',
      // 'service.namespace': 'default',
      // 'service.instance.id': 'alacritty-change-color-scheme-01',
      // 'service.version': '0.0.1',
    },
  },
  spanProcessors: [
    // new BatchSpanProcessor(exporter, {
    //   maxQueueSize: 100,
    //   scheduledDelayMillis: 5000,
    // }),
    new SimpleSpanProcessor(exporter),
    new SimpleSpanProcessor(consoleExporter),
  ],
});
provider.register({
  contextManager: new AsyncHooksContextManager().enable(),
});

const dbusSpanEmitter = new EventEmitter();

dbusSpanEmitter.on('new-root-span', onNewRootSpan);

/** @typedef {{spanId: string, name: string, parentId?: string, startTime?: opentelemetry.TimeInput, attributes?: opentelemetry.Attributes}} StartSpan */
/** @typedef {{spanId: string, endTime?: opentelemetry.TimeInput}} EndSpan */

/** @param {opentelemetry.Tracer} tracer,
 *  @param {StartSpan} spanData */
function emitNewRootSpanEvent(tracer, spanData) {
  dbusSpanEmitter.emit('new-root-span', tracer, spanData);
}

/** @param {StartSpan} childSpanData */
function emitNewChildSpanEvent(parentSpanId, childSpanData) {
  dbusSpanEmitter.emit(`new-child-span-for/${parentSpanId}`, childSpanData);
}

/** @param {EndSpan} endSpanData */
function emitEndSpanEvent(endSpanData) {
  dbusSpanEmitter.emit(`end-span-for/${endSpanData.spanId}`, endSpanData);
}

/** @param {opentelemetry.Tracer} tracer
 *  @param {StartSpan} spanData */
function onNewRootSpan(tracer, spanData) {
  console.log(`New span: ${spanData.spanId}`);
  setupActiveSpan(tracer, spanData);
}

/** @param {opentelemetry.Tracer} tracer
 *  @param {StartSpan} spanData */
function setupActiveSpan(tracer, spanData) {
  const SPAN_TIMEOUT = 1_000_000; // 1000 seconds
  const SPAN_TIMEOUT_SHORT = 10_000; // 10 seconds
  if (typeof spanData.startTime === 'number') {
    console.warn(
      'startTime is a number, not a hrTime tuple. This would use perfomance.now() in the wrong context, so we are ignoring it.',
    );
    spanData.startTime = undefined;
  }
  tracer.startActiveSpan(
    spanData.name,
    { startTime: spanData.startTime, attributes: spanData.attributes },
    span => {
      let activeContext = opentelemetry.context.active();

      /** @param {{spanId: string, name: string}} childSpanData */
      function onNewChildSpan(childSpanData) {
        opentelemetry.context.with(activeContext, () => {
          console.log(`New child span: ${childSpanData.spanId}`);
          setupActiveSpan(tracer, childSpanData);
        });
      }
      dbusSpanEmitter.on(`new-child-span-for/${spanData.spanId}`, onNewChildSpan);

      const removeTimeoutOnEnd = new AbortController();

      /** @param {{endTime?: opentelemetry.TimeInput}} endSpanData */
      function onEndSpan(endSpanData) {
        opentelemetry.context.with(activeContext, () => {
          console.log(`End span: ${spanData.spanId}`);
          if (typeof endSpanData.endTime === 'number') {
            console.warn(
              'endTime is a number, not a hrTime tuple. This would use perfomance.now() in the wrong context, so we are ignoring it.',
            );
            endSpanData.endTime = undefined;
          }
          span.end(endSpanData.endTime);
          // we don’t remove the child span listener here, because in theory child spans don’t have to be inside parent spans.
          // However, we only want to keep the child span listener around for a little more, so let’s set a shorter timeout here
          setTimeout(SPAN_TIMEOUT_SHORT).then(() => {
            dbusSpanEmitter.off(`new-child-span-for/${spanData.spanId}`, onNewChildSpan);
          });
          // remove the general long timeout belove
          removeTimeoutOnEnd.abort();
        });
      }
      dbusSpanEmitter.once(`end-span-for/${spanData.spanId}`, onEndSpan);

      // don't keep spans contexts open forever if we never get a second message
      // but we don’t end the spans, just remove the listeners.
      setTimeout(SPAN_TIMEOUT, undefined, { signal: removeTimeoutOnEnd.signal })
        .then(() => {
          console.warn(
            `Timeout for span ${spanData.spanId}, removing all event listeners`,
          );
          dbusSpanEmitter.off(`new-child-span-for/${spanData.spanId}`, onNewChildSpan);
          dbusSpanEmitter.off(`end-span-for/${spanData.spanId}`, onEndSpan);
        })
        .catch(err => {
          if (err.name === 'AbortError') {
            // console.log(`Timeout for span ${spanData.spanId} was aborted`);
          } else {
            throw err;
          }
        });
    },
  );
}

// set XDG_CONFIG_HOME if it's not set
if (!process.env.XDG_CONFIG_HOME) {
  process.env.XDG_CONFIG_HOME = process.env.HOME + '/.config';
}

function getThemePathSync(theme) {
  const path = `${themeDir}/${theme}.toml`;
  const absolutePath = fs.realpathSync(path);
  assert(fs.existsSync(absolutePath), `Theme file not found: ${absolutePath}`);
  return absolutePath;
}

/** write new color scheme
 *
 * @param {'prefer-dark' | 'prefer-light'} cs
 */
function writeAlacrittyColorConfig(cs) {
  const theme = cs === 'prefer-dark' ? darkTheme : lightTheme;
  console.log(`
    Writing color scheme ${cs} with theme ${theme}`);
  fs.writeFileSync(
    process.env.XDG_CONFIG_HOME + '/alacritty/alacritty-colors-autogen.toml',
    `# !! THIS FILE IS GENERATED BY ${programName}
general.import = ["${theme}"]`,
    'utf8',
  );
}

/** Typescript type that returns the inner value type T from a Promise<T>
 * type PromiseVal<T> = T extends Promise<infer U> ? U : T;
 * @template T
 * @typedef {T extends Promise<infer U> ? U : T } PromiseVal
 */

/**
 * @template {{[key: string]: (...args: any[]) => Promise<unknown>}} T
 * @typedef {typeof Bus.prototype.getObject<T>} GetObject<T>
 */

/**
 * @template {{[key: string]: (...args: any[]) => Promise<unknown>}} T
 * @typedef {PromiseVal<ReturnType<GetObject<T>>>} IfaceReturn<T> */

/** get the current value of the color scheme from dbus
 *
 * @returns {Promise<'prefer-dark' | 'prefer-light'>}
 */
async function getColorScheme() {
  /** @typedef {{ReadOne: (interface: string, settingName: string) => Promise<[unknown, ['prefer-dark' | 'prefer-light']]>}} ColorScheme */
  /** @type {IfaceReturn<ColorScheme>} */
  let iface = await bus.getObject(
    'org.freedesktop.portal.Desktop',
    'org.freedesktop.portal.Settings',
    '/org/freedesktop/portal/desktop',
  );

  const [_, [value]] = await iface.ReadOne('org.gnome.desktop.interface', 'color-scheme');
  assert(value === 'prefer-dark' || value === 'prefer-light');
  return value;
}

/** promisify an object method and annotate any errors that get thrown
 * @template {Function} A
 * @param {object} obj
 * @param {A} method
 * @param {string} msg
 * @param  {...any} args
 * @returns {Promise<ReturnType<A>>}
 */
function promisifyMethodAnnotate(obj, method, msg, ...args) {
  return promisify(method.bind(obj))(...args).catch(annotateErr(msg));
}

/** write respective alacritty config if the colorscheme changes.
 * Colorscheme changes are only tracked in-between calls to this function in-memory.
 */
function writeAlacrittyColorConfigIfDifferent(cs) {
  // only change the color scheme if it's different from the previous one
  let previous = null;
  if (previous === cs) {
    console.log(`Color scheme already set to ${cs}`);
    return;
  }
  previous = cs;

  console.log(`Color scheme changed to ${cs}`);
  writeAlacrittyColorConfig(cs);
}

/** Listen on the freedesktop SettingChanged dbus interface for the color-scheme setting to change. */
async function listenForColorschemeChange() {
  /** @type {PromiseVal<ReturnType<typeof bus.getObject<{}>>>} */
  const iface = await bus.getObject(
    'org.freedesktop.portal.Desktop',
    'org.freedesktop.portal.Settings',
    '/org/freedesktop/portal/desktop',
  );

  // Listen for SettingChanged signals
  iface.on('SettingChanged', (interfaceName, key, [_, [newValue]]) => {
    if (interfaceName === 'org.gnome.desktop.interface' && key == 'color-scheme') {
      writeAlacrittyColorConfigIfDifferent(newValue);
    }
  });

  console.log('Listening for color scheme changes...');
}

/** Create a dbus service that binds against the interface de.profpatsch.alacritty.ColorScheme and implements the method SetColorScheme */
async function exportColorSchemeDbusInterface() {
  console.log('Exporting color scheme interface de.profpatsch.alacritty.ColorScheme');
  const ifaceName = 'de.profpatsch.alacritty.ColorScheme';
  const iface = {
    name: 'de.profpatsch.alacritty.ColorScheme',
    methods: {
      SetColorScheme: ['s', ''],
    },
  };

  const ifaceImpl = {
    SetColorScheme: function (cs) {
      console.log(`SetColorScheme called with ${cs}`);
      writeAlacrittyColorConfigIfDifferent(cs);
    },
  };

  try {
    bus;
    const retCode = await bus.requestName(ifaceName, 0);
    console.log(
      `Request name returned ${retCode} for interface de.profpatsch.alacritty.ColorScheme`,
    );
    bus.exportInterface(ifaceImpl, '/de/profpatsch/alacritty/ColorScheme', iface);
    console.log('Exported interface de.profpatsch.alacritty.ColorScheme');
  } catch (err) {
    console.log('Error exporting interface de.profpatsch.alacritty.ColorScheme');
    console.error(err);
  }
}

/** Annotate an error as a promise .catch handler (rethrows the annotated error)
 * @param {string} msg
 * @returns {function(Error): void}
 */
function annotateErr(msg) {
  return err => {
    msg = err.message ? `${msg}: ${err.message}` : msg;
    err.message = msg;
    throw err;
  };
}

const bus2 = new Bus('otel', 'session');
async function exportOtelInterface() {
  console.log('Exporting OpenTelemetry interface');

  try {
    const retCode = bus2.requestName('de.profpatsch.otel.Tracer', 0);
    console.log(
      `Request name returned ${retCode} for interface de.profpatsch.otel.Tracer`,
    );

    const traceIface = {
      name: 'de.profpatsch.otel.Tracer',
      methods: {
        // These both just take a json string as input
        StartSpan: ['s', ''],
        EndSpan: ['s', ''],
        // An array of [(isStartSpan: bool, span: Span)]
        // So that you don’t have to call dbus for every span
        BatchSpans: ['a(bs)', ''],
      },
    };
    /** @type {(arg: {tracer: opentelemetry.Tracer, tracerName: string}) => {StartSpan: (input: string) => void, EndSpan: (input: string) => void, BatchSpans: (input: [boolean, string][]) => void }} */
    const traceImpl = tracer => ({
      StartSpan: function (input) {
        // TODO: actually verify json input
        /** @type {StartSpan} */
        const spanArgs = JSON.parse(input);
        if (spanArgs.parentId === undefined) {
          console.log(
            `Tracing root span ${spanArgs.name} with tracer ${tracer.tracerName}`,
          );
          emitNewRootSpanEvent(tracer.tracer, spanArgs);
        } else {
          console.log(
            `Tracing child span ${spanArgs.name} with tracer ${tracer.tracerName}`,
          );
          emitNewChildSpanEvent(spanArgs.parentId, spanArgs);
        }
      },
      EndSpan: function (input) {
        // TODO: actually verify json input
        /** @type {EndSpan} */
        const spanArgs = JSON.parse(input);
        console.log(`Ending span ${spanArgs.spanId} with tracer ${tracer.tracerName}`);
        emitEndSpanEvent(spanArgs);
      },
      BatchSpans: function (input) {
        // lol
        for (const [isStartSpan, span] of input) {
          if (isStartSpan) {
            traceImpl(tracer).StartSpan(span);
          } else {
            traceImpl(tracer).EndSpan(span);
          }
        }
      },
    });
    bus2.exportInterface(
      {
        CreateTracer: function (tracerName) {
          console.log(`Creating tracer with name ${tracerName}`);
          const tracer = opentelemetry.trace.getTracer(tracerName, '0.0.1');
          bus2.exportInterface(
            traceImpl({ tracer, tracerName }),
            `/de/profpatsch/otel/tracers/${tracerName}`,
            traceIface,
          );
          return `/de/profpatsch/otel/tracers/${tracerName}`;
        },
      },
      '/de/profpatsch/otel/TracerFactory',
      {
        name: 'de.profpatsch.otel.TracerFactory',
        methods: {
          CreateTracer: ['s', 's'],
        },
      },
    );
    console.log('Exported interface de.profpatsch.otel.TracerFactory');
  } catch (err) {
    console.log('Error exporting interface de.profpatsch.alacritty.ColorScheme');
    console.error(err);
  }
}

/** Returns the callsite of the function calling `getParentCallsite`, if any. */
async function getParentCallsite() {
  const getCallsites = (await import('callsites')).default;
  const cs = getCallsites();
  return cs[2] ?? cs[1] ?? null;
}

/** Calls the tracer dbus interface, sets up a tracer
 *
 * @param {string} tracerName The name of the tracer to set up
 * @returns {Promise<{
 *   StartSpan: (spanData: StartSpan) => Promise<void>,
 *   EndSpan: (spanData: EndSpan) => Promise<void>,
 *   BatchSpans: (spans: ([true, StartSpan] | [false, EndSpan])[]) => Promise<void>
 * }>}
 */
async function setupTracer(tracerName) {
  const parentCallsite = await getParentCallsite();
  console.log(`Setting up tracer ${tracerName} from ${parentCallsite?.getFileName()}`);

  /** @typedef {{CreateTracer: (name: string) => Promise<string>}} TracerFactory */
  /** @type {IfaceReturn<TracerFactory>} */
  const iface = await bus2.getObject(
    'de.profpatsch.otel.Tracer',
    'de.profpatsch.otel.TracerFactory',
    '/de/profpatsch/otel/TracerFactory',
  );
  const path = await iface.CreateTracer(tracerName);

  /**
   *  @typedef {{
   *    StartSpan: (spanData: string) => Promise<void>,
   *    EndSpan: (spanData: string) => Promise<void>
   *    BatchSpans: ([bool, string]) => Promise<void>
   * }} Tracer
   *  @type {IfaceReturn<Tracer>}
   * */
  const tracerIface = await bus2.getObject(
    'de.profpatsch.otel.Tracer',
    'de.profpatsch.otel.Tracer',
    path,
  );

  function StartSpan(spanData) {
    return tracerIface.StartSpan(JSON.stringify(spanData));
  }
  function EndSpan(spanData) {
    return tracerIface.EndSpan(JSON.stringify(spanData));
  }
  function BatchSpans(spans) {
    return tracerIface.BatchSpans(
      spans.map(([isStartSpan, span]) => [isStartSpan, JSON.stringify(span)]),
    );
  }
  return {
    StartSpan,
    EndSpan,
    BatchSpans,
  };
}

async function main() {
  await exportOtelInterface();

  const tracer = await setupTracer('hello');
  await tracer.StartSpan({
    name: 'hello',
    spanId: 'hello',
    startTime: hrTime(),
    attributes: {
      foo: 'bar',
    },
  });
  await tracer.StartSpan({
    name: 'world',
    spanId: 'world',
    parentId: 'hello',
    attributes: {
      bar: 'baz',
    },
  });
  await tracer.EndSpan({
    spanId: 'world',
    endTime: hrTime(),
  });
  await tracer.EndSpan({
    spanId: 'hello',
    endTime: hrTime(),
  });
  const t = performance.now();
  await tracer.BatchSpans([
    [
      true,
      {
        name: 'batchy',
        spanId: 'batchy',
        startTime: t,
        attributes: { foo: 'bar' },
      },
    ],
    [
      true,
      {
        name: 'worldy',
        spanId: 'worldy',
        parentId: 'batchy',
        startTime: t + 100,
        attributes: { bar: 'baz' },
      },
    ],
    [false, { spanId: 'worldy', endTime: t + 500 }],
    [false, { spanId: 'batchy', endTime: t + 1000 }],
  ]);

  await exportColorSchemeDbusInterface();

  // get the current color scheme
  const currentColorScheme = await getColorScheme();
  console.log(`Current color scheme: ${currentColorScheme}`);

  // write the color scheme
  writeAlacrittyColorConfig(currentColorScheme);

  // listen for color scheme changes
  await listenForColorschemeChange();
}

main().catch(err => {
  console.error(err);
});
